#!/bin/sh
set -eu

name="JRectangle Local Development"
keychain=$(/usr/bin/security default-keychain -d user)
keychain=$(printf '%s\n' "$keychain" | sed 's/^[[:space:]]*"//; s/"[[:space:]]*$//')

find_identity() {
    output=$(/usr/bin/security find-identity -v -p codesigning "$keychain") || return
    printf '%s\n' "$output" |
        awk -v name="\"$name\"" '$3 " " $4 " " $5 == name { print $2 }'
}

require_identity() {
    identities=$(find_identity)
    count=$(printf '%s\n' "$identities" | awk 'NF { count++ } END { print count+0 }')
    if [ "$count" != 1 ]; then
        echo "Expected one valid '$name' identity in $keychain; found $count." >&2
        echo "Check its certificate, private key and code-signing trust in Keychain Access. Do not replace an existing identity just to rebuild." >&2
        exit 1
    fi
    printf '%s\n' "$identities"
}

identities=$(find_identity)
if [ -n "$identities" ]; then
    require_identity
    exit 0
fi

if /usr/bin/security find-certificate -c "$name" "$keychain" >/dev/null 2>&1; then
    echo "'$name' exists but is not a valid signing identity." >&2
    echo "Unlock $keychain and check its private key, expiry and code-signing trust in Keychain Access. No replacement was created." >&2
    exit 1
fi

echo "Creating '$name' in $keychain." >&2
echo "macOS may request Keychain access and permission to trust this certificate for code signing." >&2

umask 077
temporary=$(mktemp -d "${TMPDIR:-/tmp}/JRectangle-signing.XXXXXX")
cleanup() {
    rm -f "$temporary/key.pem" "$temporary/certificate.pem" \
        "$temporary/identity.p12" "$temporary/openssl.cnf" "$temporary/password"
    rmdir "$temporary"
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

cat > "$temporary/openssl.cnf" <<EOF
[req]
distinguished_name = subject
x509_extensions = codesign
prompt = no
[subject]
CN = $name
[codesign]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
EOF

/usr/bin/openssl rand -base64 32 > "$temporary/password"
/usr/bin/openssl genrsa -aes256 -passout "file:$temporary/password" \
    -out "$temporary/key.pem" 3072
/usr/bin/openssl req -new -x509 -sha256 -days 3650 \
    -key "$temporary/key.pem" -passin "file:$temporary/password" \
    -out "$temporary/certificate.pem" \
    -config "$temporary/openssl.cnf"
/usr/bin/openssl pkcs12 -export -name "$name" \
    -passin stdin -passout "file:$temporary/password" \
    -keypbe PBE-SHA1-3DES -certpbe PBE-SHA1-3DES -macalg sha1 \
    -inkey "$temporary/key.pem" -in "$temporary/certificate.pem" \
    -out "$temporary/identity.p12" < "$temporary/password"
/usr/bin/security import "$temporary/identity.p12" -k "$keychain" \
    -P "$(cat "$temporary/password")" -T /usr/bin/codesign >&2
/usr/bin/security add-trusted-cert -r trustRoot -p codeSign \
    -k "$keychain" "$temporary/certificate.pem" >&2

require_identity

from cryptography import x509
from cryptography.x509.oid import NameOID
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.primitives.serialization import pkcs12
import datetime

# 1️⃣ Generate private key
key = rsa.generate_private_key(
    public_exponent=65537,
    key_size=2048
)

# 2️⃣ Create self-signed certificate
subject = issuer = x509.Name([
    x509.NameAttribute(NameOID.COMMON_NAME, u"dbdome")
])
cert = x509.CertificateBuilder().subject_name(subject)\
    .issuer_name(issuer)\
    .public_key(key.public_key())\
    .serial_number(x509.random_serial_number())\
    .not_valid_before(datetime.datetime.utcnow())\
    .not_valid_after(datetime.datetime.utcnow() + datetime.timedelta(days=365))\
    .add_extension(x509.BasicConstraints(ca=True, path_length=None), critical=True)\
    .sign(key, hashes.SHA256())

# 3️⃣ Export to PFX (PKCS#12)
pfx_password = b"Yd2243796Anz!!"
pfx_bytes = pkcs12.serialize_key_and_certificates(
    name=b"dbdome",
    key=key,
    cert=cert,
    cas=None,
    encryption_algorithm=serialization.BestAvailableEncryption(pfx_password)
)

# 4️⃣ Write PFX to file
with open(r"C:\dev\dbanalytics\certification\dbdome_cert.pfx", "wb") as f:
    f.write(pfx_bytes)

print("PFX certificate created at C:\dev\dbanalytics\certification\\dbdome_cert.pfx")
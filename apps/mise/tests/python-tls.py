"""Real Python SSL: public CA, self-signed rejection and explicit private CA."""
import json
from pathlib import Path
import socket
import ssl
import sys
import threading
import urllib.request

base = Path(sys.argv[1])
with urllib.request.urlopen('https://pypi.org/simple/markupsafe/', timeout=20) as response:
    assert response.status == 200 and response.read(64)


def local_handshake(trust_fixture):
    server = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    server.load_cert_chain(base / 'cert.pem', base / 'key.pem')
    listener = socket.socket()
    listener.bind(('127.0.0.1', 0))
    listener.listen(1)
    listener.settimeout(5)
    port = listener.getsockname()[1]
    results = []

    def serve():
        try:
            connection, _ = listener.accept()
            connection.settimeout(5)
            with server.wrap_socket(connection, server_side=True) as peer:
                peer.sendall(b'verified')
                results.append('accepted')
        except ssl.SSLError:
            results.append('rejected')
        finally:
            listener.close()

    worker = threading.Thread(target=serve, daemon=True)
    worker.start()
    client = ssl.create_default_context()
    if trust_fixture:
        client.load_verify_locations(base / 'cert.pem')
    assert client.verify_mode == ssl.CERT_REQUIRED and client.check_hostname
    try:
        with socket.create_connection(('127.0.0.1', port), timeout=5) as raw:
            with client.wrap_socket(raw, server_hostname='localhost') as peer:
                assert trust_fixture and peer.recv(8) == b'verified'
    except ssl.SSLCertVerificationError:
        assert not trust_fixture
    worker.join(6)
    assert not worker.is_alive() and results == [('accepted' if trust_fixture else 'rejected')], results


local_handshake(False)
local_handshake(True)
print(json.dumps({'public_CA_TLS': 'passed', 'untrusted_certificate_rejected': 'passed',
                  'explicit_private_CA_TLS': 'passed', 'openssl': ssl.OPENSSL_VERSION}))

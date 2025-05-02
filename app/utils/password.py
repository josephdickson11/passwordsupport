def generate_fernet_key():
    from cryptography.fernet import Fernet
    key = Fernet.generate_key()
    return key.decode()

def generate_secret_key():
    import secrets
    return secrets.token_hex(32)
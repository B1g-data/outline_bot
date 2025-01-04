from outline_vpn.outline_vpn import OutlineVPN

class OutlineAPI:
    def __init__(self, OUTLINE_API_URL, CERT_SHA256):
        self.client = OutlineVPN(api_url=OUTLINE_API_URL, cert_sha256=CERT_SHA256)

    def get_keys(self):
        return self.client.get_keys()

    def create_key(self, name):
        return self.client.create_key(name=name)

    def delete_key(self, key_id):
        self.client.delete_key(key_id)

    def add_data_limit(self, key_id, limit):
        self.client.add_data_limit(key_id, limit)

    def delete_data_limit(self, key_id):
        self.client.delete_data_limit(key_id)

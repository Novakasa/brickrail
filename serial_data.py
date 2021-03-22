import json

class SerialData:

    @classmethod
    def from_hub_msg(cls, msg):
        obj = eval(msg.split("data::")[1])
        key = obj["key"]
        data = obj["data"]
        return cls(key, data)

    def __init__(self, key, data):
        self.key = key
        self.data = data
    
    def to_json(self):
        obj = {"key": self.key, "data": self.data}
        return json.dumps(obj)
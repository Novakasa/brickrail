import json

class SerialData:

    @classmethod
    def from_hub_msg(cls, msg):
        obj = eval(msg.split("data::")[1])
        key = obj["key"]
        data = obj["data"]
        hub = obj.get("hub", None)
        return cls(key, hub, data)

    def __init__(self, key, hub, data):
        self.key = key
        self.hub = hub
        self.data = data
    
    def to_json(self):
        obj = {"key": self.key, "hub": self.hub, "data": self.data}
        return json.dumps(obj)
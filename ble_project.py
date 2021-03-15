from ble_train import BLETrain

class BLEProject:

    def __init__(self):

        self.trains = {}
    
    def add_train(self, name, address=None):
        self.trains[name] = BLETrain(name, address)
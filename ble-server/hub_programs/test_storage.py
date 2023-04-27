from io_hub_unfrozen import IOHub

class TestDevice:
    
    def update(self, delta):
        pass
    
    def print_address(self, address):
        # print(address)
        print("storage value:", io_hub.storage[int(address)])

device = TestDevice()
io_hub = IOHub(device)

io_hub.run_loop()
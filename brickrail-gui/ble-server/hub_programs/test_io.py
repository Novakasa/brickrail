from io_hub import IOHub

class TestDevice:
    
    def update(self, delta):
        pass

    def respond(self, data):
        io_hub.emit_data("test", [byte for byte in data])

device = TestDevice()
io_hub = IOHub(device)

io_hub.run_loop()
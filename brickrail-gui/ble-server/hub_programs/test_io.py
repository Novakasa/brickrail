from io_hub import IOHub

class TestDevice:
    
    def update(self, delta):
        pass

    def respond(self):
        io_hub.emit_data("test", [42, 44])

device = TestDevice()
io_hub = IOHub(device)

io_hub.run_loop()
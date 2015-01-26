# websockets
import websocket
from urllib import urlopen
import json
# interact with interpreter
import sys
import thread

IDENTIFICATION_DICT = {'role': 'pc', 'key': 'automationlab'}

# production
HOSTNAME = 'romo-comm-server.herokuapp.com'
PORT = 80
# development
# HOSTNAME = 'localhost'
# PORT = 8000

EVENT_TEMPLATE = "5:::{\"name\":\"%s\",\"args\":[%s]}"
WS_URL_TEMPLATE = "ws://%s:%d/socket.io/1/websocket/%s"
WS_URL = None

def noop(socket):
    pass

class RomoSocket:
    def __init__(self, init_callback=noop, partnered=noop):
        connect()
        ws = websocket.WebSocketApp(WS_URL,
                                    on_message = lambda ws, msg: self.on_message(msg),
                                    on_error = lambda ws, err: self.on_error(err),
                                    on_close = lambda ws: self.on_close())
        ws.on_open = lambda ws: self.on_open()

        self.ws = ws
        print "set self: {0}".format(self.ws)
        self.is_partnered = False
        self.init_callback = init_callback
        self.partnered = partnered
        thread.start_new_thread(ws.run_forever, ())
        # ws.run_forever()

    # HANDLE SOCKET MESSAGES

    def on_message(self, message):
        print "on_message: {0}".format(message)
        message_type = message[:3]

        if message_type == '5::':
            data = decode(message)
            name =  data['name']

            if name == 'initial':
                self.send_event('identification', IDENTIFICATION_DICT)
                self.init_callback(self)
            elif name == 'partnered':
                self.is_partnered = True
                self.partnered(self)
            elif name == 'freed':
                self.is_partnered = False

        elif message_type == '2::':
            self.emit_heartbeat()

    def on_error(self, error):
        print error

    def on_close(self):
        print "### closed ###"

    def on_open(self):
        print '### opened ###'

    # SOCKET SEND CONVENIENCE METHODS

    def send(self, message):
        self.ws.send(message)

    def emit_heartbeat(self):
        self.send('2::')

    def send_event(self, event, data):
        self.send(EVENT_TEMPLATE % (event, json.dumps(data)))

    def send_command(self, name, data):
        self.send_event('sendCommand', {'name': name, 'data': data})

    # DRIVE CONVENIENCE METHODS

    def send_turn(self, direction, power):
        self.send_command('start/turn', {'direction': direction, 'power': power})

    def send_turn_to_heading(self, heading):
        self.send_command('start/turnToHeading', {'heading': heading})

    def send_drive_forward(self, speed):
        self.send_command('start/driveForward', {'speed': speed})

    def send_drive_forward_seconds(self, seconds):
        self.send_command('start/driveForwardForSeconds', {'seconds': seconds})

    def send_drive_backward(self, speed):
        self.send_command('start/driveBackward', {'speed': speed})

    def send_drive_backward_seconds(self, seconds):
        self.send_command('start/driveBackwardForSeconds', {'seconds': seconds})

    def send_stop(self):
        self.send_command('stop', {})

def decode(message):
    return json.loads(message[4:])

def connect():
    global WS_URL
    websocket.enableTrace(True)
    try:
        (sid, hbtimeout, ctimeout) = handshake(HOSTNAME, PORT)
        WS_URL = WS_URL_TEMPLATE % (HOSTNAME, PORT, sid)
        print 'ctimeout: ' + ctimeout
    except Exception as e:
        print e
        sys.exit(1)

def handshake(host, port):
    u = urlopen("http://%s:%d/socket.io/1/" % (host, port))

    if u.getcode() == 200:
        response = u.readline()
        (sid, hbtimeout, ctimeout, supported) = response.split(":")
        supportedlist = supported.split(",")

        if "websocket" in supportedlist:
            return (sid, hbtimeout, ctimeout)
        else:
            raise TransportException()
    else:
        raise InvalidResponseException()

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Drives greetd through bin/fenrir-greet-bridge, which turns greetd's
// length-prefixed binary frames into the newline-delimited JSON a plain
// SplitParser can read.
//
// greetd's exchange is a small state machine and every reply is just
// "success" or "error", so which request a reply belongs to is only knowable
// from the phase we were in when it arrived - hence the explicit phase below
// rather than a pile of booleans.
Singleton {
    id: root

    // idle -> creating -> authenticating -> starting, with cancelling as the
    // path back to idle after a failure.
    property string phase: "idle"

    property string username: ""
    property string prompt: ""
    property string message: ""
    property string error: ""
    property bool secret: true

    // True when greetd asked something the login form can't answer by itself,
    // such as a second factor, and the UI has to show its own prompt.
    property bool needsInput: false

    // Lets the single password the form already collected answer PAM's first
    // secret prompt without a round trip back through the UI.
    property string pendingPassword: ""

    // The session Exec line to hand greetd once authentication succeeds.
    property string sessionCommand: ""

    readonly property bool busy: root.phase !== "idle"

    signal sessionStarted

    function send(request: var): void {
        bridge.write(JSON.stringify(request) + "\n");
    }

    function reset(): void {
        root.phase = "idle";
        root.needsInput = false;
        root.prompt = "";
        root.pendingPassword = "";
    }

    function login(username: string, password: string, command: string): void {
        if (root.busy)
            return;
        root.error = "";
        root.message = "";
        root.username = username;
        root.pendingPassword = password;
        root.sessionCommand = command;
        root.phase = "creating";
        root.send({
            type: "create_session",
            username: username
        });
    }

    function respond(text: string): void {
        root.needsInput = false;
        root.prompt = "";
        root.send({
            type: "post_auth_message_response",
            response: text
        });
    }

    function handleAuthMessage(msg: var): void {
        root.phase = "authenticating";
        const kind = msg.auth_message_type;

        if (kind === "secret" && root.pendingPassword.length > 0) {
            const password = root.pendingPassword;
            root.pendingPassword = "";
            root.respond(password);
            return;
        }

        if (kind === "secret" || kind === "visible") {
            root.secret = kind === "secret";
            root.prompt = msg.auth_message;
            root.needsInput = true;
            return;
        }

        // info and error carry nothing to answer, but PAM still wants a reply.
        root.message = msg.auth_message;
        root.send({
            type: "post_auth_message_response"
        });
    }

    function handle(msg: var): void {
        if (msg.type === "auth_message") {
            root.handleAuthMessage(msg);
        } else if (msg.type === "success") {
            if (root.phase === "cancelling") {
                root.reset();
            } else if (root.phase === "starting") {
                root.sessionStarted();
            } else {
                // Authentication is done; nothing runs until we say so.
                root.phase = "starting";
                root.send({
                    type: "start_session",
                    cmd: ["sh", "-lc", root.sessionCommand],
                    env: []
                });
            }
        } else if (msg.type === "error") {
            // The cancel we sent after a failure answers with its own reply;
            // treating that as a new failure would loop.
            if (root.phase === "cancelling") {
                root.reset();
                return;
            }
            root.error = msg.description ?? qsTr("Authentication failed");
            root.pendingPassword = "";
            root.needsInput = false;
            root.prompt = "";
            root.phase = "cancelling";
            root.send({
                type: "cancel_session"
            });
        } else if (msg.type === "closed" && root.phase === "starting") {
            // greetd drops the socket once the session is live.
            root.sessionStarted();
        }
    }

    Process {
        id: bridge

        running: true
        command: ["/usr/lib/fenrir-greeter/fenrir-greet-bridge"]
        stdout: SplitParser {
            onRead: data => {
                if (data.trim().length > 0)
                    root.handle(JSON.parse(data));
            }
        }
    }
}

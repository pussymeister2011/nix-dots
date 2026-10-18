{ pkgs, ... }: {
  home.packages = [
    pkgs.ags
    pkgs.networkmanager
    pkgs.bluez
    pkgs.wireplumber
  ];

  # --- COMPILING THE LIVE INTERFACE FILES ---
  xdg.configFile."ags/app.js".text = ''
    const App = ags.App;
    const Widget = ags.Widget;
    const Audio = ags.Service.Audio;
    const Network = ags.Service.Network;
    const Bluetooth = ags.Service.Bluetooth;
    const Battery = ags.Service.Battery;

    // --- SYSTEM TIME INDICATOR ---
    const Clock = () => Widget.Label({
        className: "clock",
        setup: self => self.poll(1000, label => {
            const date = new Date();
            label.label = date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) + " · " + date.toLocaleDateString([], { month: 'short', day: '2-digit' });
        }),
    });

    // --- NATIVE AUDIO DROPDOWN MIXER ---
    const AudioMenu = () => Widget.Box({
        vertical: true,
        className: "dropdown-card",
        children: [
            Widget.Label({ label: "Audio Mixer", className: "menu-title" }),
            Widget.Box({
                children: [
                    Widget.Button({
                        onClicked: () => Audio.speaker.isMuted = !Audio.speaker.isMuted,
                        child: Widget.Label({
                            setup: self => self.hook(Audio, label => {
                                label.label = Audio.speaker.isMuted ? "vol mute" : `vol ''${Math.round(Audio.speaker.volume * 100)}%`;
                            }),
                        }),
                    }),
                    Widget.Slider({
                        hexpand: true,
                        drawValue: false,
                        onChange: ({ value }) => Audio.speaker.volume = value,
                        setup: self => self.hook(Audio, () => {
                            self.value = Audio.speaker.volume || 0;
                        }),
                    }),
                ],
            }),
        ],
    });

    // --- NATIVE WI-FI DROPDOWN CONTROL ---
    const WifiMenu = () => Widget.Box({
        vertical: true,
        className: "dropdown-card",
        children: [
            Widget.Label({ label: "Wireless Network", className: "menu-title" }),
            Widget.Button({
                className: "menu-toggle",
                onClicked: () => Network.wifi.enabled = !Network.wifi.enabled,
                child: Widget.Label({
                    setup: self => self.hook(Network, label => {
                        label.label = Network.wifi.enabled ? "Disable Wi-Fi" : "Enable Wi-Fi";
                    }),
                }),
            }),
            Widget.Label({
                setup: self => self.hook(Network, label => {
                    label.label = Network.wifi.ssid ? `Connected: ''${Network.wifi.ssid}` : "Disconnected";
                }),
            }),
        ],
    });

    // --- NATIVE BLUETOOTH DROPDOWN CONTROL ---
    const BluetoothMenu = () => Widget.Box({
        vertical: true,
        className: "dropdown-card",
        children: [
            Widget.Label({ label: "Bluetooth Devices", className: "menu-title" }),
            Widget.Button({
                className: "menu-toggle",
                onClicked: () => Bluetooth.toggle(),
                child: Widget.Label({
                    setup: self => self.hook(Bluetooth, label => {
                        label.label = Bluetooth.enabled ? "Turn Off" : "Turn On";
                    }),
                }),
            }),
        ],
    });

    // --- GENERIC WINDOW OVERLAY MECHANICS ---
    const PopupWindow = (name, content) => Widget.Window({
        name,
        popup: true,
        visible: false,
        focusable: true,
        anchor: ["top"],
        child: content,
    });

    const audioPopup = PopupWindow("audio-menu", AudioMenu());
    const wifiPopup = PopupWindow("wifi-menu", WifiMenu());
    const btPopup = PopupWindow("bt-menu", BluetoothMenu());

    // --- MAIN STATUS BAR LAYER ---
    const Bar = () => Widget.Window({
        name: "bar",
        anchor: ["top", "left", "right"],
        exclusivity: "exclusive",
        child: Widget.CenterBox({
            className: "bar-container",
            startWidget: Widget.Box({
                children: [
                    Widget.Label({ label: "❯ niri", className: "wm-tag" }),
                ],
            }),
            centerWidget: Clock(),
            endWidget: Widget.Box({
                hpack: "end",
                spacing: 12,
                children: [
                    Widget.Button({
                        onClicked: () => App.toggleWindow("wifi-menu"),
                        child: Widget.Label({
                            setup: self => self.hook(Network, label => {
                                label.label = Network.wifi.ssid ? `wifi ''${Network.wifi.ssid}` : "wifi none";
                            }),
                        }),
                    }),
                    Widget.Button({
                        onClicked: () => App.toggleWindow("bt-menu"),
                        child: Widget.Label({
                            setup: self => self.hook(Bluetooth, label => {
                                label.label = Bluetooth.enabled ? `bt ''${Bluetooth.connectedDevices.length}` : "bt off";
                            }),
                        }),
                    }),
                    Widget.Button({
                        onClicked: () => App.toggleWindow("audio-menu"),
                        child: Widget.Label({
                            setup: self => self.hook(Audio, label => {
                                label.label = Audio.speaker.isMuted ? "vol mute" : `vol ''${Math.round(Audio.speaker.volume * 100)}%`;
                            }),
                        }),
                    }),
                    Widget.Label({
                        setup: self => self.poll(2000, label => {
                            label.label = "cpu " + parseInt(Utils.exec("bash -c \"top -bn1 | grep 'Cpu(s)' | awk '{print \\$2}'\"")) + "%";
                        }),
                    }),
                    Widget.Label({
                        setup: self => self.hook(Battery, label => {
                            label.label = `bat ''${Battery.percent}%`;
                        }),
                    }),
                ],
            }),
        ]),
    });

    App.config({
        style: App.configDir + "/style.css",
        windows: [ Bar(), audioPopup, wifiPopup, btPopup ]
    });
  '';

  # --- STYLESHEET (FOREST STYLE) ---
  xdg.configFile."ags/style.css".text = ''
    * {
        font-family: "Noto Sans", sans-serif;
        font-size: 13px;
        font-weight: bold;
    }

    #bar {
        background-color: #1a231e;
        color: #e1e8e2;
        border-bottom: 2px solid #879a72;
    }

    .bar-container {
        padding: 4px 12px;
        height: 24px;
    }

    .wm-tag {
        color: #a9b665;
    }

    button {
        background: transparent;
        border: none;
        color: #e1e8e2;
    }

    button:hover {
        color: #a9b665;
    }

    .dropdown-card {
        background-color: #1a231e;
        border: 2px solid #879a72;
        border-radius: 6px;
        padding: 16px;
        min-width: 240px;
        margin-top: 4px;
    }

    .menu-title {
        color: #a9b665;
        font-size: 14px;
        margin-bottom: 12px;
    }

    .menu-toggle {
        background-color: #2d3b32;
        padding: 6px;
        border-radius: 4px;
        margin-bottom: 8px;
    }
  '';
}

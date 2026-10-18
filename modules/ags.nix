{ inputs, pkgs, ... }:

let
  # forest palette
  c = {
    bg     = "rgba(10, 24, 17, 0.88)";
    pill   = "rgba(31, 61, 43, 0.75)";
    border = "rgba(127, 176, 105, 0.25)";
    fg     = "#cfe8d5";
    dim    = "#6f8f7a";
    moss   = "#7fb069";
    leaf   = "#a3c585";
    amber  = "#d9a441";
    red    = "#c9524a";
  };

  appTsx = ''
    import { App, Astal, Gtk, Gdk } from "astal/gtk3"
    import { Variable, bind, GLib } from "astal"
    import { subprocess, execAsync } from "astal/process"
    import Network from "gi://AstalNetwork"
    import Wp from "gi://AstalWp"
    import Bluetooth from "gi://AstalBluetooth"
    import Battery from "gi://AstalBattery"
    import Tray from "gi://AstalTray"
    import style from "./style.scss"

    // ---------- Nerd Font glyphs (codepoints) ----------
    const I = {
      leaf: "\uf06c",
      wsFocused: "\uf111",
      wsOther: "\uf10c",
      clock: "\uf017",
      wifi: "\uf1eb",
      wifiOff: "\u{f05aa}",
      ethernet: "\u{f0200}",
      volHigh: "\uf028",
      volLow: "\uf027",
      volMute: "\uf026",
      bt: "\uf293",
      btConnected: "\u{f00b1}",
      btOff: "\u{f00b2}",
      bolt: "\uf0e7",
      bat: ["\uf244", "\uf243", "\uf242", "\uf241", "\uf240"],
    }

    // ---------- niri state ----------
    const workspaces = Variable<any[]>([])
    const focused = Variable<any>(null)

    async function refresh() {
      try {
        const ws = JSON.parse(await execAsync(["niri", "msg", "--json", "workspaces"]))
        ws.sort((a: any, b: any) =>
          String(a.output).localeCompare(String(b.output)) || a.idx - b.idx)
        workspaces.set(ws)
        focused.set(JSON.parse(await execAsync(["niri", "msg", "--json", "focused-window"])))
      } catch (e) {
        console.error(e)
      }
    }

    function startNiri() {
      refresh()
      subprocess(
        ["niri", "msg", "--json", "event-stream"],
        () => refresh(),
        (err) => console.error(err),
      )
    }

    // ---------- modules ----------
    function Workspaces() {
      return (
        <box className="workspaces">
          {bind(workspaces).as((list) =>
            list.map((ws: any) => (
              <button
                className={
                  ws.is_focused ? "ws focused" : ws.is_active ? "ws active" : "ws"
                }
                onClicked={() =>
                  execAsync(["niri", "msg", "action", "focus-workspace", String(ws.idx)])
                }
              >
                <label label={ws.is_focused ? I.wsFocused : I.wsOther} />
              </button>
            )),
          )}
        </box>
      )
    }

    function Title() {
      return (
        <box className="module title">
          <label className="icon" label={I.leaf} />
          <label
            truncate
            maxWidthChars={50}
            label={bind(focused).as((w) => (w && w.title ? w.title : "Desktop"))}
          />
        </box>
      )
    }

    function Clock() {
      const time = Variable("").poll(
        1000,
        () => GLib.DateTime.new_now_local().format("%a %d %b  %H:%M")!,
      )
      return (
        <box className="module clock">
          <label className="icon" label={I.clock} />
          <label label={bind(time)} />
        </box>
      )
    }

    function NetworkModule() {
      const network = Network.get_default()
      const wifi = network.wifi
      return (
        <box className="module network">
          {bind(network, "primary").as((p) => {
            if (p === Network.Primary.WIRED)
              return <label className="icon" label={I.ethernet} />
            if (p === Network.Primary.WIFI && wifi)
              return (
                <box>
                  <label className="icon" label={I.wifi} />
                  <label label={bind(wifi, "ssid").as((s) => s || "")} />
                </box>
              )
            return <label className="icon off" label={I.wifiOff} />
          })}
        </box>
      )
    }

    function Audio() {
      const speaker = Wp.get_default()!.audio.defaultSpeaker
      const state = Variable.derive(
        [bind(speaker, "volume"), bind(speaker, "mute")],
        (v, m) => ({
          icon: m ? I.volMute : v < 0.4 ? I.volLow : I.volHigh,
          text: m ? "muted" : Math.round(v * 100) + "%",
          muted: m,
        }),
      )
      return (
        <eventbox
          onClick={() => (speaker.mute = !speaker.mute)}
          onScroll={(_, e) => {
            const v = speaker.volume - Math.sign(e.delta_y) * 0.03
            speaker.volume = Math.max(0, Math.min(1, v))
          }}
        >
          <box className={bind(state).as((s) => (s.muted ? "module audio off" : "module audio"))}>
            <label className="icon" label={bind(state).as((s) => s.icon)} />
            <label label={bind(state).as((s) => s.text)} />
          </box>
        </eventbox>
      )
    }

    function BluetoothModule() {
      const bt = Bluetooth.get_default()
      const icon = Variable.derive(
        [bind(bt, "isPowered"), bind(bt, "isConnected")],
        (p, c) => (!p ? I.btOff : c ? I.btConnected : I.bt),
      )
      return (
        <box className={bind(bt, "isPowered").as((p) => (p ? "module bluetooth" : "module bluetooth off"))}>
          <label className="icon" label={bind(icon)} />
        </box>
      )
    }

    function BatteryModule() {
      const bat = Battery.get_default()
      const state = Variable.derive(
        [bind(bat, "percentage"), bind(bat, "charging")],
        (p, c) => {
          const pct = Math.round(p * 100)
          const idx = Math.min(4, Math.floor(p * 5))
          return {
            icon: c ? I.bolt : I.bat[idx],
            text: pct + "%",
            cls: c ? "charging" : pct <= 15 ? "critical" : pct <= 30 ? "low" : "",
          }
        },
      )
      return (
        <box
          visible={bind(bat, "isPresent")}
          className={bind(state).as((s) => "module battery " + s.cls)}
        >
          <label className="icon" label={bind(state).as((s) => s.icon)} />
          <label label={bind(state).as((s) => s.text)} />
        </box>
      )
    }

    function SysTray() {
      const tray = Tray.get_default()
      return (
        <box className="module tray">
          {bind(tray, "items").as((items) =>
            items.map((item) => (
              <menubutton
                tooltipMarkup={bind(item, "tooltipMarkup")}
                usePopover={false}
                actionGroup={bind(item, "actionGroup").as((ag) => ["dbusmenu", ag])}
                menuModel={bind(item, "menuModel")}
              >
                <icon gicon={bind(item, "gicon")} />
              </menubutton>
            )),
          )}
        </box>
      )
    }

    // ---------- bar ----------
    function Bar(gdkmonitor: Gdk.Monitor) {
      const { TOP, LEFT, RIGHT } = Astal.WindowAnchor
      return (
        <window
          className="Bar"
          gdkmonitor={gdkmonitor}
          exclusivity={Astal.Exclusivity.EXCLUSIVE}
          anchor={TOP | LEFT | RIGHT}
          application={App}
        >
          <centerbox className="bar">
            <box halign={Gtk.Align.START}>
              <Workspaces />
              <Title />
            </box>
            <box>
              <Clock />
            </box>
            <box halign={Gtk.Align.END}>
              <Audio />
              <NetworkModule />
              <BluetoothModule />
              <BatteryModule />
              <SysTray />
            </box>
          </centerbox>
        </window>
      )
    }

    App.start({
      css: style,
      main() {
        startNiri()
        App.get_monitors().map(Bar)
      },
    })
  '';

  styleScss = ''
    * {
      font-family: "JetBrainsMono Nerd Font", monospace;
      font-size: 13px;
    }

    window.Bar {
      background: transparent;
      color: ${c.fg};
    }

    .bar {
      background: ${c.bg};
      border: 1px solid ${c.border};
      border-radius: 14px;
      margin: 6px 8px 0 8px;
      padding: 3px 6px;
    }

    .module {
      background: ${c.pill};
      border-radius: 10px;
      padding: 2px 12px;
      margin: 2px 3px;
    }

    .module .icon {
      color: ${c.moss};
      margin-right: 6px;
    }

    .module .icon:last-child { margin-right: 0; }

    .module.off, .module .off { color: ${c.dim}; }
    .module.off .icon { color: ${c.dim}; }

    .title .icon { color: ${c.leaf}; }
    .clock { color: ${c.leaf}; font-weight: bold; }

    /* workspaces */
    .workspaces {
      background: ${c.pill};
      border-radius: 10px;
      padding: 0 4px;
      margin: 2px 3px;
    }

    .ws {
      background: transparent;
      border: none;
      box-shadow: none;
      border-radius: 8px;
      padding: 0 7px;
      color: ${c.dim};
      min-height: 0;
      min-width: 0;
    }

    .ws:hover { background: rgba(127, 176, 105, 0.15); }
    .ws.active { color: ${c.leaf}; }
    .ws.focused { color: ${c.moss}; }

    /* battery states */
    .battery.charging .icon { color: ${c.leaf}; }
    .battery.low { color: ${c.amber}; }
    .battery.low .icon { color: ${c.amber}; }
    .battery.critical { color: ${c.red}; }
    .battery.critical .icon { color: ${c.red}; }

    /* tray */
    .tray menubutton button {
      background: transparent;
      border: none;
      box-shadow: none;
      padding: 0 4px;
      min-height: 0;
      min-width: 0;
    }

    tooltip {
      background: ${c.bg};
      border: 1px solid ${c.border};
      border-radius: 8px;
    }
  '';

  tsconfig = builtins.toJSON {
    compilerOptions = {
      experimentalDecorators = true;
      strict = true;
      target = "ES2022";
      module = "ES2022";
      moduleResolution = "Bundler";
      jsx = "react-jsx";
      jsxImportSource = "astal/gtk3";
    };
  };
in
{
  imports = [ inputs.ags.homeManagerModules.default ];

  home.packages = [ pkgs.nerd-fonts.jetbrains-mono ];
  fonts.fontconfig.enable = true;

  programs.ags = {
    enable = true;

    configDir = pkgs.linkFarm "ags-bar" [
      { name = "app.tsx";       path = pkgs.writeText "app.tsx" appTsx; }
      { name = "style.scss";    path = pkgs.writeText "style.scss" styleScss; }
      { name = "tsconfig.json"; path = pkgs.writeText "tsconfig.json" tsconfig; }
    ];

    extraPackages = with inputs.ags.packages.${pkgs.system}; [
      network
      wireplumber
      bluetooth
      battery
      tray
    ];
  };
}

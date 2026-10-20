{ inputs, pkgs, ... }:

let
  # forest palette
  c = {
    bg     = "rgba(10, 24, 17, 0.92)";
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
    import { Variable, bind, GLib, timeout, interval } from "astal"
    import { subprocess, execAsync } from "astal/process"
    import { readFile } from "astal/file"
    import Gio from "gi://Gio"
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
      lock: "\uf023",
      kbd: "\uf11c",
      sun: "\uf185",
      mic: "\uf130",
      micOff: "\uf131",
      power: "\uf011",
      suspend: "\uf186",
      logout: "\uf08b",
      reboot: "\u{f0709}",
      saver: "\uf06c",
      balanced: "\uf24e",
      perf: "\uf0e7",
      check: "\uf00c",
      refresh: "\uf021",
      cpu: "\uf2db",
      gpu: "\u{f08ae}",
      disk: "\uf0a0",
      volHigh: "\uf028",
      volLow: "\uf027",
      volMute: "\uf026",
      bt: "\uf293",
      btConnected: "\u{f00b1}",
      btOff: "\u{f00b2}",
      bolt: "\uf0e7",
      bat: ["\uf244", "\uf243", "\uf242", "\uf241", "\uf240"],
    }

    // ---------- menu state ----------
    const openMenu = Variable<string>("")
    const toggleMenu = (name: string) =>
      openMenu.set(openMenu.get() === name ? "" : name)

    // ---------- niri state ----------
    const workspaces = Variable<any[]>([])
    const focused = Variable<any>(null)
    const layout = Variable<string>("")

    async function refresh() {
      try {
        const ws = JSON.parse(await execAsync(["niri", "msg", "--json", "workspaces"]))
        ws.sort((a: any, b: any) =>
          String(a.output).localeCompare(String(b.output)) || a.idx - b.idx)
        workspaces.set(ws)
        focused.set(JSON.parse(await execAsync(["niri", "msg", "--json", "focused-window"])))
        const kl = JSON.parse(await execAsync(["niri", "msg", "--json", "keyboard-layouts"]))
        layout.set(kl.names[kl.current_idx])
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

    // ---------- bar modules ----------
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

    const layoutShort = (n: string) => {
      const map: Record<string, string> = {
        English: "EN", Russian: "RU", Japanese: "JA",
        German: "DE", French: "FR", Spanish: "ES",
      }
      const first = n.split(/[ (]/)[0]
      return map[first] || first.slice(0, 2).toUpperCase()
    }

    function LayoutButton() {
      return (
        <eventbox
          visible={bind(layout).as((l) => l !== "")}
          onClick={() =>
            execAsync(["niri", "msg", "action", "switch-layout", "next"]).catch(console.error)
          }
        >
          <box className="module layout">
            <label className="icon" label={I.kbd} />
            <label label={bind(layout).as(layoutShort)} />
          </box>
        </eventbox>
      )
    }

    function Clock() {
      const time = Variable("").poll(
        1000,
        () => GLib.DateTime.new_now_local().format("%a %d %b  %H:%M")!,
      )
      return (
        <eventbox onClick={() => toggleMenu("calendar")}>
          <box className="module clock">
            <label className="icon" label={I.clock} />
            <label label={bind(time)} />
          </box>
        </eventbox>
      )
    }

    function NetworkModule() {
      const network = Network.get_default()
      const wifi = network.wifi
      return (
        <eventbox onClick={() => toggleMenu("wifi")}>
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
        </eventbox>
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
          onClick={(_, e) => {
            if (e.button === Astal.MouseButton.PRIMARY) toggleMenu("audio")
            else if (e.button === Astal.MouseButton.SECONDARY) speaker.mute = !speaker.mute
          }}
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
        <eventbox onClick={() => toggleMenu("bluetooth")}>
          <box className={bind(bt, "isPowered").as((p) => (p ? "module bluetooth" : "module bluetooth off"))}>
            <label className="icon" label={bind(icon)} />
          </box>
        </eventbox>
      )
    }

    // brightnessctl -m prints: device,class,current,percent,max
    const brightness = Variable<number>(1).poll(
      2000,
      ["brightnessctl", "-m"],
      (out) => parseInt(out.trim().split(",")[3]) / 100,
    )

    function setBrightness(v: number) {
      const pct = Math.max(1, Math.min(100, Math.round(v * 100)))
      brightness.set(pct / 100)
      execAsync(["brightnessctl", "set", pct + "%"]).catch(console.error)
    }

    function BrightnessModule() {
      return (
        <eventbox
          onClick={() => toggleMenu("brightness")}
          onScroll={(_, e) => setBrightness(brightness.get() - Math.sign(e.delta_y) * 0.05)}
        >
          <box className="module brightness">
            <label className="icon" label={I.sun} />
            <label label={bind(brightness).as((v) => Math.round(v * 100) + "%")} />
          </box>
        </eventbox>
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
        <box
          className="module tray"
          visible={bind(tray, "items").as((items) => items.length > 0)}
        >
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

    function PowerButton() {
      return (
        <eventbox onClick={() => toggleMenu("power")}>
          <box className="module power">
            <label className="icon" label={I.power} />
          </box>
        </eventbox>
      )
    }

    // ---------- mic level meter (only runs while the sound menu is open) ----------
    const micLevel = Variable<number>(0)
    let micProc: any = null
    let micTimer: any = null
    let peakAcc = 0

    function startMicMeter() {
      if (micProc) return
      peakAcc = 0
      micProc = subprocess(
        ["sh", "-c", "parec --format=s16le --rate=8000 --channels=1 --latency-msec=50 | od -An -t d2 -w32 -v"],
        (line: string) => {
          for (const n of line.trim().split(/\s+/))
            peakAcc = Math.max(peakAcc, Math.abs(Number(n) || 0))
        },
        (err: string) => console.error(err),
      )
      micTimer = interval(80, () => {
        micLevel.set(Math.min(1, peakAcc / 8000))
        peakAcc = 0
      })
    }

    function stopMicMeter() {
      if (micTimer) { micTimer.cancel(); micTimer = null }
      if (micProc) { micProc.kill(); micProc = null }
      execAsync(["pkill", "-f", "parec --format=s16le --rate=8000"]).catch(() => {})
      micLevel.set(0)
    }

    openMenu.subscribe((m) => (m === "audio" ? startMicMeter() : stopMicMeter()))

    // ---------- dropdown: sound ----------
    function DeviceList(prop: string, audio: any) {
      return (list: any[]) =>
        list.map((ep) => {
          const isDef = bind(audio, prop).as((d: any) => !!d && d.id === ep.id)
          return (
            <button
              className={isDef.as((d) => (d ? "fm-item active" : "fm-item"))}
              onClicked={() =>
                execAsync(["wpctl", "set-default", String(ep.id)]).catch(console.error)
              }
            >
              <box>
                <label className="icon" label={isDef.as((d) => (d ? I.check : " "))} />
                <label truncate xalign={0} hexpand maxWidthChars={34} label={ep.description || ep.name} />
              </box>
            </button>
          )
        })
    }

    function StreamRow(s: any) {
      return (
        <box vertical className="fm-stream">
          <box>
            <label
              className="fm-app"
              truncate
              hexpand
              xalign={0}
              maxWidthChars={28}
              label={s.description || s.name || "App"}
            />
            <label
              className="fm-val"
              label={bind(s, "volume").as((v) => Math.round(v * 100) + "%")}
            />
          </box>
          <box>
            <button className="fm-btn" onClicked={() => (s.mute = !s.mute)}>
              <label label={bind(s, "mute").as((m) => (m ? I.volMute : I.volHigh))} />
            </button>
            <slider
              hexpand
              value={bind(s, "volume")}
              onDragged={({ value }) => (s.volume = value)}
            />
          </box>
        </box>
      )
    }

    function AudioMenu() {
      const audio = Wp.get_default()!.audio
      const speaker = audio.defaultSpeaker
      return (
        <box vertical className="fm-box audio">
          <label className="fm-title" xalign={0} label="Sound" />

          <label className="fm-sub" xalign={0} label="Output" />
          <box className="fm-row">
            <button className="fm-btn" onClicked={() => (speaker.mute = !speaker.mute)}>
              <label label={bind(speaker, "mute").as((m) => (m ? I.volMute : I.volHigh))} />
            </button>
            <slider
              hexpand
              value={bind(speaker, "volume")}
              onDragged={({ value }) => (speaker.volume = value)}
            />
            <label
              className="fm-val"
              label={bind(speaker, "volume").as((v) => Math.round(v * 100) + "%")}
            />
          </box>
          <box vertical>{bind(audio, "speakers").as(DeviceList("defaultSpeaker", audio))}</box>

          <label className="fm-sub" xalign={0} label="Input" />
          {bind(audio, "defaultMicrophone").as((mic) =>
            mic ? (
              <box vertical>
                <box className="fm-row">
                  <button className="fm-btn" onClicked={() => (mic.mute = !mic.mute)}>
                    <label label={bind(mic, "mute").as((m) => (m ? I.micOff : I.mic))} />
                  </button>
                  <slider
                    hexpand
                    value={bind(mic, "volume")}
                    onDragged={({ value }) => (mic.volume = value)}
                  />
                  <label
                    className="fm-val"
                    label={bind(mic, "volume").as((v) => Math.round(v * 100) + "%")}
                  />
                </box>
                <levelbar className="fm-level" value={bind(micLevel)} />
              </box>
            ) : (
              <label className="fm-sub" xalign={0} label="No microphone found" />
            ),
          )}
          <box vertical>{bind(audio, "microphones").as(DeviceList("defaultMicrophone", audio))}</box>

          <label
            className="fm-sub"
            xalign={0}
            label="Applications"
            visible={bind(audio, "streams").as((s) => s.length > 0)}
          />
          <box vertical>
            {bind(audio, "streams").as((list) => list.slice(0, 6).map(StreamRow))}
          </box>
        </box>
      )
    }

    // ---------- dropdown: wifi ----------
    const wifiPw = Variable<string>("")   // ssid waiting for a password
    const wifiMsg = Variable<string>("")

    async function wifiConnect(ssid: string, pw?: string) {
      wifiMsg.set("Connecting...")
      try {
        await execAsync(
          pw
            ? ["nmcli", "device", "wifi", "connect", ssid, "password", pw]
            : ["nmcli", "device", "wifi", "connect", ssid],
        )
        wifiMsg.set("")
        wifiPw.set("")
      } catch (e) {
        if (!pw) {
          wifiMsg.set("")
          wifiPw.set(ssid)
        } else {
          wifiMsg.set("Could not connect. Wrong password?")
        }
      }
    }

    function WifiMenu() {
      const network = Network.get_default()
      const wifi = network.wifi
      if (!wifi) {
        return (
          <box vertical className="fm-box">
            <label className="fm-title" xalign={0} label="Wi-Fi" />
            <label className="fm-sub" xalign={0} label="No wifi adapter found" />
          </box>
        )
      }
      return (
        <box vertical className="fm-box">
          <box className="fm-head">
            <label className="fm-title" hexpand xalign={0} label="Wi-Fi" />
            <button className="fm-btn" onClicked={() => wifi.scan()}>
              <label label={I.refresh} />
            </button>
            <switch
              valign={Gtk.Align.CENTER}
              active={bind(wifi, "enabled")}
              onNotifyActive={({ active }) => (wifi.enabled = active)}
            />
          </box>
          <box vertical>
            {bind(wifi, "accessPoints").as((aps) => {
              const seen = new Set<string>()
              return [...aps]
                .sort((a, b) => b.strength - a.strength)
                .filter((ap) => {
                  if (!ap.ssid || seen.has(ap.ssid)) return false
                  seen.add(ap.ssid)
                  return true
                })
                .slice(0, 8)
                .map((ap) => (
                  <button
                    className={bind(wifi, "ssid").as((s) =>
                      s === ap.ssid ? "fm-item active" : "fm-item",
                    )}
                    onClicked={() => wifiConnect(ap.ssid)}
                  >
                    <box>
                      <label className="icon" label={ap.requiresPassword ? I.lock : I.wifi} />
                      <label truncate xalign={0} hexpand maxWidthChars={26} label={ap.ssid} />
                      <label className="fm-val" label={Math.round(ap.strength) + "%"} />
                    </box>
                  </button>
                ))
            })}
          </box>
          <box vertical visible={bind(wifiPw).as((s) => s !== "")}>
            <label
              className="fm-sub"
              xalign={0}
              label={bind(wifiPw).as((s) => "Password for " + s)}
            />
            <entry
              visibility={false}
              placeholderText="Password, then Enter"
              onActivate={({ text }) => wifiConnect(wifiPw.get(), text)}
            />
          </box>
          <label
            className="fm-sub"
            xalign={0}
            visible={bind(wifiMsg).as((s) => s !== "")}
            label={bind(wifiMsg)}
          />
        </box>
      )
    }

    // ---------- dropdown: bluetooth ----------
    async function btToggleDevice(d: any) {
      try {
        if (d.connected) {
          await execAsync(["bluetoothctl", "disconnect", d.address])
        } else {
          if (!d.paired) {
            await execAsync(["bluetoothctl", "pair", d.address])
            await execAsync(["bluetoothctl", "trust", d.address])
          }
          await execAsync(["bluetoothctl", "connect", d.address])
        }
      } catch (e) {
        console.error(e)
      }
    }

    function BluetoothMenu() {
      const bt = Bluetooth.get_default()
      return (
        <box vertical className="fm-box">
          <box className="fm-head">
            <label className="fm-title" hexpand xalign={0} label="Bluetooth" />
            <button
              className="fm-btn"
              onClicked={() =>
                execAsync(["bluetoothctl", "--timeout", "10", "scan", "on"]).catch(console.error)
              }
            >
              <label label={I.refresh} />
            </button>
            <switch
              valign={Gtk.Align.CENTER}
              active={bind(bt, "isPowered")}
              onNotifyActive={({ active }) =>
                execAsync(["bluetoothctl", "power", active ? "on" : "off"]).catch(console.error)
              }
            />
          </box>
          <box vertical>
            {bind(bt, "devices").as((devs) =>
              [...devs]
                .filter((d) => d.alias || d.name)
                .sort((a, b) => Number(b.connected) - Number(a.connected))
                .slice(0, 8)
                .map((d) => (
                  <button
                    className={bind(d, "connected").as((x) => (x ? "fm-item active" : "fm-item"))}
                    onClicked={() => btToggleDevice(d)}
                  >
                    <box>
                      <label
                        className="icon"
                        label={bind(d, "connected").as((x) => (x ? I.btConnected : I.bt))}
                      />
                      <label truncate xalign={0} hexpand maxWidthChars={26} label={d.alias || d.name} />
                      <label
                        className="fm-val"
                        label={bind(d, "connected").as((x) => (x ? "connected" : d.paired ? "paired" : ""))}
                      />
                    </box>
                  </button>
                )),
            )}
          </box>
        </box>
      )
    }

    // ---------- dropdown: power + profiles ----------
    const armed = Variable<string>("")

    const profile = Variable<string>("balanced").poll(
      3000,
      ["powerprofilesctl", "get"],
      (out) => out.trim(),
    )

    // two-click confirmation for destructive actions (used by the menu and the dashboard)
    function runPower(id: string, cmd: string[], confirm: boolean) {
      if (confirm && armed.get() !== id) {
        armed.set(id)
        timeout(3000, () => {
          if (armed.get() === id) armed.set("")
        })
        return
      }
      armed.set("")
      openMenu.set("")
      execAsync(cmd).catch(console.error)
    }

    function PowerRow(id: string, icon: string, text: string, cmd: string[], confirm: boolean) {
      return (
        <button
          className={bind(armed).as((a) => (a === id ? "fm-item danger" : "fm-item"))}
          onClicked={() => runPower(id, cmd, confirm)}
        >
          <box>
            <label className="icon" label={icon} />
            <label
              xalign={0}
              hexpand
              label={bind(armed).as((a) => (a === id ? "Click again to confirm" : text))}
            />
          </box>
        </button>
      )
    }

    function PowerMenu() {
      const profiles: [string, string, string][] = [
        ["power-saver", I.saver, "Power saver"],
        ["balanced", I.balanced, "Balanced"],
        ["performance", I.perf, "Performance"],
      ]
      return (
        <box vertical className="fm-box power">
          <label className="fm-title" xalign={0} label="Power" />
          {PowerRow("lock", I.lock, "Lock", ["swaylock", "-f"], false)}
          {PowerRow("suspend", I.suspend, "Suspend", ["systemctl", "suspend"], false)}
          {PowerRow("logout", I.logout, "Log out", ["niri", "msg", "action", "quit", "--skip-confirmation"], true)}
          {PowerRow("reboot", I.reboot, "Reboot", ["systemctl", "reboot"], true)}
          {PowerRow("poweroff", I.power, "Shut down", ["systemctl", "poweroff"], true)}
          <label className="fm-sub" xalign={0} label="Power profile" />
          {profiles.map(([id, icon, text]) => (
            <button
              className={bind(profile).as((p) => (p === id ? "fm-item active" : "fm-item"))}
              onClicked={() =>
                execAsync(["powerprofilesctl", "set", id])
                  .then(() => profile.set(id))
                  .catch(console.error)
              }
            >
              <box>
                <label className="icon" label={icon} />
                <label xalign={0} hexpand label={text} />
              </box>
            </button>
          ))}
        </box>
      )
    }

    // ---------- dropdown: brightness ----------
    function BrightnessMenu() {
      return (
        <box vertical className="fm-box">
          <label className="fm-title" xalign={0} label="Brightness" />
          <box className="fm-row">
            <slider
              hexpand
              value={bind(brightness)}
              onDragged={({ value }) => setBrightness(value)}
            />
            <label
              className="fm-val"
              label={bind(brightness).as((v) => Math.round(v * 100) + "%")}
            />
          </box>
        </box>
      )
    }

    // ---------- calendar (shared by the dropdown and the dashboard) ----------
    function makeCalendar() {
      // raw GTK3 widgets start hidden, so it has to be shown explicitly
      const cal = new Gtk.Calendar({ visible: true })

      // highlight a day only when the shown month is the current one
      const sync = () => {
        const now = GLib.DateTime.new_now_local()
        if (cal.year === now.get_year() && cal.month === now.get_month() - 1)
          cal.select_day(now.get_day_of_month())
        else
          cal.select_day(0)
      }

      const goToday = () => {
        const now = GLib.DateTime.new_now_local()
        cal.select_month(now.get_month() - 1, now.get_year())
        cal.select_day(now.get_day_of_month())
      }

      cal.connect("month-changed", sync)
      goToday()
      return { cal, goToday }
    }

    function CalendarMenu() {
      const { cal, goToday } = makeCalendar()
      openMenu.subscribe((m) => {
        if (m === "calendar") goToday()
      })
      return (
        <box vertical className="fm-box">
          {cal}
        </box>
      )
    }

    // ---------- dashboard: stats ----------
    // set to false if you have an NVIDIA GPU on a laptop and do not want
    // nvidia-smi to wake it up (see notes)
    const ALLOW_NVIDIA_SMI = true

    const cpu = Variable<number>(0)
    const gpu = Variable<number>(0)
    const gpuAvail = Variable<boolean>(false)
    const disks = Variable<{ label: string; frac: number; text: string }[]>([])

    let prevTotal = 0
    let prevIdle = 0

    function readCpu() {
      try {
        const line = readFile("/proc/stat").split("\n")[0]
        const v = line.trim().split(/\s+/).slice(1).map(Number)
        const idle = v[3] + (v[4] || 0)
        const total = v.slice(0, 8).reduce((a, b) => a + b, 0)
        if (prevTotal > 0) {
          const dt = total - prevTotal
          const di = idle - prevIdle
          cpu.set(dt > 0 ? Math.max(0, Math.min(1, 1 - di / dt)) : 0)
        }
        prevTotal = total
        prevIdle = idle
      } catch (e) {
        console.error(e)
      }
    }

    let gpuMode: "unknown" | "sysfs" | "nvidia" | "none" = "unknown"
    let gpuPath = ""

    function probeGpu() {
      for (let i = 0; i < 4; i++) {
        const p = "/sys/class/drm/card" + i + "/device/gpu_busy_percent"
        if (GLib.file_test(p, GLib.FileTest.EXISTS)) {
          gpuMode = "sysfs"
          gpuPath = p
          gpuAvail.set(true)
          return
        }
      }
      if (ALLOW_NVIDIA_SMI && GLib.find_program_in_path("nvidia-smi")) {
        gpuMode = "nvidia"
        gpuAvail.set(true)
        return
      }
      gpuMode = "none"
    }

    function readGpu() {
      if (gpuMode === "unknown") probeGpu()
      if (gpuMode === "sysfs") {
        try {
          gpu.set(Math.min(1, parseInt(readFile(gpuPath)) / 100))
        } catch (e) {
          console.error(e)
        }
      } else if (gpuMode === "nvidia") {
        execAsync(["nvidia-smi", "--query-gpu=utilization.gpu", "--format=csv,noheader,nounits"])
          .then((out) => gpu.set(Math.min(1, parseInt(out.trim()) / 100)))
          .catch(() => {
            gpuMode = "none"
            gpuAvail.set(false)
          })
      }
    }

    const fmtSize = (bytes: number) => {
      const g = bytes / 1073741824
      return g >= 1000 ? (g / 1024).toFixed(1) + "T" : Math.round(g) + "G"
    }

    function readDisks() {
      const home = GLib.get_home_dir()

      // filesystem id of a path, or null when it does not exist
      const fsId = (p: string): string | null => {
        try {
          return Gio.File.new_for_path(p)
            .query_info("id::filesystem", Gio.FileQueryInfoFlags.NONE, null)
            .get_attribute_string("id::filesystem")
        } catch (e) {
          return null
        }
      }
      const rootId = fsId("/")

      // [label, path, only show when mounted]
      const targets: [string, string, boolean][] = [
        ["/", "/", false],
        ["~/HDD", home + "/HDD", true],
        ["~/SSD", home + "/SSD", true],
      ]

      const list: { label: string; frac: number; text: string }[] = []
      for (const [label, path, optional] of targets) {
        if (optional) {
          const id = fsId(path)
          if (id === null || id === rootId) continue   // missing, or just a folder on /
        }
        try {
          const info = Gio.File.new_for_path(path).query_filesystem_info(
            "filesystem::size,filesystem::used,filesystem::free",
            null,
          )
          const total = info.get_attribute_uint64("filesystem::size")
          // same definition of "used" as df and fastfetch
          const used = info.has_attribute("filesystem::used")
            ? info.get_attribute_uint64("filesystem::used")
            : total - info.get_attribute_uint64("filesystem::free")
          list.push({
            label,
            frac: total > 0 ? used / total : 0,
            text: fmtSize(used) + " / " + fmtSize(total),
          })
        } catch (e) {
          list.push({ label, frac: 0, text: "n/a" })
        }
      }
      disks.set(list)
    }

    // polling starts once at launch (the dashboard is always visible now)
    let statTimer: any = null
    let diskTimer: any = null

    function startStats() {
      if (statTimer) return
      prevTotal = 0
      readCpu()
      readGpu()
      readDisks()
      timeout(500, readCpu)
      statTimer = interval(2000, () => {
        readCpu()
        readGpu()
      })
      diskTimer = interval(15000, readDisks)
    }

    // ---------- dashboard: widgets ----------
    const bigTime = Variable("").poll(
      1000,
      () => GLib.DateTime.new_now_local().format("%H:%M")!,
    )
    const bigDate = Variable("").poll(
      30000,
      () => GLib.DateTime.new_now_local().format("%A, %d %B %Y")!,
    )

    function StatRow(icon: string, name: string, frac: any, text: any) {
      return (
        <box vertical className="dash-stat">
          <box>
            <label className="icon" label={icon} />
            <label className="dash-stat-name" xalign={0} hexpand label={name} />
            <label className="fm-val" label={text} />
          </box>
          <levelbar className="dash-bar" hexpand value={frac} />
        </box>
      )
    }

    function PowerTile(
      id: string,
      icon: string,
      text: string,
      cmd: string[],
      confirm: boolean,
      extra = "",
    ) {
      return (
        <button
          hexpand
          vexpand
          className={bind(armed).as(
            (a) => (a === id ? "dash-btn danger" : "dash-btn") + (extra ? " " + extra : ""),
          )}
          tooltipText={bind(armed).as((a) => (a === id ? "Click again to confirm" : text))}
          onClicked={() => runPower(id, cmd, confirm)}
        >
          <label label={icon} />
        </button>
      )
    }

    // ---------- popup windows ----------
    const BAR_OFFSET = 46

    // transparent catcher under the menus: click anywhere outside to close
    function Scrim() {
      const { TOP, BOTTOM, LEFT, RIGHT } = Astal.WindowAnchor
      return (
        <window
          className="Scrim"
          namespace="ags-scrim"
          application={App}
          layer={Astal.Layer.TOP}
          exclusivity={Astal.Exclusivity.IGNORE}
          anchor={TOP | BOTTOM | LEFT | RIGHT}
          marginTop={BAR_OFFSET}
          visible={bind(openMenu).as((m) => m !== "")}
        >
          <eventbox expand onButtonPressEvent={() => openMenu.set("")}>
            <box expand />
          </eventbox>
        </window>
      )
    }

    function MenuWindow(name: string, content: Gtk.Widget, center = false) {
      const { TOP, RIGHT } = Astal.WindowAnchor
      return (
        <window
          className="Menu"
          namespace="ags-menu"
          application={App}
          layer={Astal.Layer.OVERLAY}
          keymode={Astal.Keymode.ON_DEMAND}
          exclusivity={Astal.Exclusivity.IGNORE}
          anchor={center ? TOP : TOP | RIGHT}
          marginTop={BAR_OFFSET}
          marginRight={8}
          visible={bind(openMenu).as((m) => m === name)}
        >
          {content}
        </window>
      )
    }

    // ---------- dashboard window ----------
    // BOTTOM layer: above the wallpaper, below every normal window
    function Dashboard(gdkmonitor: Gdk.Monitor) {
      const { TOP, BOTTOM, LEFT, RIGHT } = Astal.WindowAnchor
      const { cal, goToday } = makeCalendar()
      cal.set_valign(Gtk.Align.CENTER)
      // the date text changes once a day: jump the calendar to the new today
      bigDate.subscribe(() => goToday())
      return (
        <window
          className="Dashboard"
          namespace="ags-dashboard"
          gdkmonitor={gdkmonitor}
          application={App}
          layer={Astal.Layer.BOTTOM}
          exclusivity={Astal.Exclusivity.IGNORE}
          keymode={Astal.Keymode.NONE}
          anchor={TOP | BOTTOM | LEFT | RIGHT}
          marginTop={BAR_OFFSET}
        >
          <box vertical homogeneous className="dash">
            <box halign={Gtk.Align.CENTER} valign={Gtk.Align.CENTER}>
              <box vertical className="dash-card dash-clockbox">
                <label className="dash-clock" label={bind(bigTime)} />
                <label className="dash-date" label={bind(bigDate)} />
              </box>
            </box>

            <box halign={Gtk.Align.CENTER} valign={Gtk.Align.CENTER} spacing={20}>
              <box className="dash-card">{cal}</box>

              <box vertical className="dash-card dash-stats">
                <box vertical vexpand valign={Gtk.Align.CENTER}>
                  {StatRow(I.cpu, "CPU", bind(cpu), bind(cpu).as((v) => Math.round(v * 100) + "%"))}
                  <box vertical visible={bind(gpuAvail)}>
                    {StatRow(I.gpu, "GPU", bind(gpu), bind(gpu).as((v) => Math.round(v * 100) + "%"))}
                  </box>
                  {bind(disks).as((list) =>
                    list.map((d) => StatRow(I.disk, d.label, d.frac, d.text)),
                  )}
                </box>
              </box>

              <box vertical className="dash-card dash-power" spacing={10}>
                <box homogeneous vexpand spacing={10}>
                  {PowerTile("lock", I.lock, "Lock", ["swaylock", "-f"], false)}
                  {PowerTile("suspend", I.suspend, "Suspend", ["systemctl", "suspend"], false)}
                </box>
                <box homogeneous vexpand spacing={10}>
                  {PowerTile("logout", I.logout, "Log out", ["niri", "msg", "action", "quit", "--skip-confirmation"], true)}
                  {PowerTile("reboot", I.reboot, "Reboot", ["systemctl", "reboot"], true)}
                </box>
                <box homogeneous vexpand>
                  {PowerTile("poweroff", I.power, "Shut down", ["systemctl", "poweroff"], true, "accent")}
                </box>
              </box>
            </box>
          </box>
        </window>
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
              <LayoutButton />
              <Audio />
              <NetworkModule />
              <BluetoothModule />
              <BrightnessModule />
              <BatteryModule />
              <SysTray />
              <PowerButton />
            </box>
          </centerbox>
        </window>
      )
    }

    App.start({
      css: style,
      main() {
        startNiri()
        const mons = App.get_monitors()
        mons.map(Bar)
        startStats()
        Dashboard(mons[0])
        Scrim()
        MenuWindow("calendar", <CalendarMenu />, true)
        MenuWindow("audio", <AudioMenu />)
        MenuWindow("wifi", <WifiMenu />)
        MenuWindow("bluetooth", <BluetoothMenu />)
        MenuWindow("brightness", <BrightnessMenu />)
        MenuWindow("power", <PowerMenu />)
      },
    })
  '';

  styleScss = ''
    * {
      font-family: "JetBrainsMono Nerd Font", monospace;
      font-size: 13px;
    }

    window.Bar, window.Menu, window.Scrim, window.Dashboard {
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
      font-size: 15px;
      margin-right: 10px;
      padding-right: 2px;
    }

    .module .icon:last-child {
      margin-right: 0;
      padding-right: 0;
    }

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

    /* power button */
    .power .icon { color: ${c.red}; }

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

    /* dropdown menus */
    .fm-box {
      background: ${c.bg};
      border: 1px solid ${c.border};
      border-radius: 14px;
      padding: 12px;
      min-width: 320px;
    }

    .fm-box.power { min-width: 240px; }
    .fm-box.audio { min-width: 360px; }

    .fm-head, .fm-row { margin-bottom: 6px; }
    .fm-title { color: ${c.leaf}; font-weight: bold; font-size: 14px; }
    .fm-sub { color: ${c.dim}; margin-top: 8px; margin-bottom: 2px; }
    .fm-val { color: ${c.dim}; margin-left: 10px; }
    .fm-stream { margin-top: 6px; }
    .fm-app { color: ${c.fg}; }
    .fm-level { margin: 2px 6px 6px 6px; }

    .fm-btn {
      background: ${c.pill};
      color: ${c.moss};
      border: none;
      box-shadow: none;
      border-radius: 8px;
      padding: 2px 10px;
      margin: 0 6px;
    }
    .fm-btn:hover { background: rgba(127, 176, 105, 0.25); }

    .fm-item {
      background: transparent;
      border: none;
      box-shadow: none;
      border-radius: 8px;
      padding: 5px 8px;
    }
    .fm-item:hover { background: rgba(127, 176, 105, 0.15); }
    .fm-item.active { background: ${c.pill}; color: ${c.leaf}; }
    .fm-item .icon { color: ${c.moss}; margin-right: 10px; }

    .fm-item.danger {
      background: rgba(201, 82, 74, 0.25);
      color: ${c.red};
    }
    .fm-item.danger .icon { color: ${c.red}; }

    scale trough, slider trough {
      background: ${c.pill};
      border-radius: 6px;
      min-height: 6px;
    }
    scale highlight, slider highlight {
      background: ${c.moss};
      border-radius: 6px;
    }
    scale slider, slider slider {
      background: ${c.leaf};
      border-radius: 50%;
      min-width: 14px;
      min-height: 14px;
      margin: -5px;
    }

    levelbar trough { min-height: 6px; }
    levelbar block.empty {
      background: ${c.pill};
      border-radius: 4px;
      min-height: 6px;
    }
    levelbar block.filled {
      background: ${c.moss};
      border-radius: 4px;
      min-height: 6px;
    }

    entry {
      background: ${c.pill};
      color: ${c.fg};
      border: 1px solid ${c.border};
      border-radius: 8px;
      padding: 4px 8px;
    }

    switch {
      background: ${c.pill};
      border: none;
      border-radius: 12px;
    }
    switch:checked { background: ${c.moss}; }
    switch slider {
      background: ${c.fg};
      border-radius: 12px;
      min-width: 18px;
      min-height: 18px;
      margin: 0;
    }

    /* calendar */
    calendar {
      background: transparent;
      color: ${c.fg};
      border: none;
      padding: 4px;
    }
    calendar.header { color: ${c.leaf}; font-weight: bold; }
    calendar.button {
      color: ${c.moss};
      background: transparent;
      border: none;
      box-shadow: none;
    }
    calendar.button:hover { background: rgba(127, 176, 105, 0.2); }
    calendar:indeterminate { color: ${c.dim}; }
    calendar:selected {
      background: ${c.moss};
      color: #0a1811;
      border-radius: 6px;
    }

    /* dashboard */
    .dash { padding: 24px 40px; }

    .dash-clock {
      font-size: 120px;
      font-weight: bold;
      color: ${c.leaf};
    }
    .dash-date {
      font-size: 22px;
      color: ${c.dim};
    }

    .dash-card {
      background: ${c.bg};
      border: 1px solid ${c.border};
      border-radius: 14px;
      padding: 16px;
    }
    .dash-card calendar { font-size: 15px; }

    .dash-stats { min-width: 340px; }
    .dash-stat { margin-bottom: 12px; }
    .dash-stat .icon {
      color: ${c.moss};
      font-size: 15px;
      margin-right: 10px;
    }
    .dash-stat-name { color: ${c.fg}; }
    .dash-bar { margin-top: 4px; }
    .dash-bar block.empty, .dash-bar block.filled { min-height: 8px; }

    .dash-clockbox { padding: 20px 56px; }

    .dash-power { min-width: 150px; }
    .dash-btn {
      background: ${c.pill};
      color: ${c.moss};
      border: none;
      box-shadow: none;
      border-radius: 14px;
      min-width: 60px;
      min-height: 52px;
    }
    .dash-btn label { font-size: 24px; }
    .dash-btn.accent { color: ${c.red}; }
    .dash-btn:hover { background: rgba(127, 176, 105, 0.25); }
    .dash-btn.danger {
      background: rgba(201, 82, 74, 0.25);
      color: ${c.red};
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

  home.packages = [
    pkgs.nerd-fonts.jetbrains-mono
    pkgs.swaylock
    pkgs.pulseaudio   # only for the parec tool (mic meter), no daemon is started
  ];
  fonts.fontconfig.enable = true;

  programs.ags = {
    enable = true;

    configDir = pkgs.runCommand "ags-bar" { } ''
      mkdir -p $out/node_modules
      cp ${pkgs.writeText "app.tsx" appTsx} $out/app.tsx
      cp ${pkgs.writeText "style.scss" styleScss} $out/style.scss
      cp ${pkgs.writeText "tsconfig.json" tsconfig} $out/tsconfig.json
      ln -s ${inputs.astal}/lang/gjs $out/node_modules/astal
    '';

    extraPackages = with inputs.ags.packages.${pkgs.stdenv.hostPlatform.system}; [
      network
      wireplumber
      bluetooth
      battery
      tray
    ];
  };
}

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
    import { Variable, bind, GLib, timeout } from "astal"
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
      lock: "\uf023",
      sun: "\uf185",
      power: "\uf011",
      suspend: "\uf186",
      logout: "\uf08b",
      reboot: "\u{f0709}",
      saver: "\uf06c",
      balanced: "\uf24e",
      perf: "\uf0e7",
      check: "\uf00c",
      refresh: "\uf021",
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
    // true iff a workspace with idx === 1 is currently focused on any output.
    // adjust idx if your niri numbers workspaces differently (check: niri msg --json workspaces)
    const firstWorkspace = Variable<boolean>(false)

    async function refresh() {
      try {
        const ws = JSON.parse(await execAsync(["niri", "msg", "--json", "workspaces"]))
        ws.sort((a: any, b: any) =>
          String(a.output).localeCompare(String(b.output)) || a.idx - b.idx)
        workspaces.set(ws)
        firstWorkspace.set(ws.some((w: any) => w.is_focused && w.idx === 1))
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

    // ---------- bar modules (UNCHANGED) ----------
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

    // ---------- dropdown: sound ----------
    function AudioMenu() {
      const audio = Wp.get_default()!.audio
      const speaker = audio.defaultSpeaker
      return (
        <box vertical className="fm-box">
          <label className="fm-title" xalign={0} label="Sound" />
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
          <label className="fm-sub" xalign={0} label="Output device" />
          <box vertical>
            {bind(audio, "speakers").as((list) =>
              list.map((ep) => (
                <button
                  className={bind(ep, "isDefault").as((d) => (d ? "fm-item active" : "fm-item"))}
                  onClicked={() => (ep.isDefault = true)}
                >
                  <box>
                    <label
                      className="icon"
                      label={bind(ep, "isDefault").as((d) => (d ? I.check : " "))}
                    />
                    <label truncate xalign={0} hexpand maxWidthChars={32} label={ep.description || ep.name} />
                  </box>
                </button>
              )),
            )}
          </box>
        </box>
      )
    }

    // ---------- dropdown: wifi ----------
    const wifiPw = Variable<string>("")
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

    function PowerRow(id: string, icon: string, text: string, cmd: string[], confirm: boolean) {
      return (
        <button
          className={bind(armed).as((a) => (a === id ? "fm-item danger" : "fm-item"))}
          onClicked={() => {
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
          }}
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

    // ---------- brightness ----------
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

    // ---------- popup windows ----------
    const BAR_OFFSET = 46

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

    function MenuWindow(name: string, content: Gtk.Widget) {
      const { TOP, RIGHT } = Astal.WindowAnchor
      return (
        <window
          className="Menu"
          namespace="ags-menu"
          application={App}
          layer={Astal.Layer.OVERLAY}
          keymode={Astal.Keymode.ON_DEMAND}
          exclusivity={Astal.Exclusivity.IGNORE}
          anchor={TOP | RIGHT}
          marginTop={BAR_OFFSET}
          marginRight={8}
          visible={bind(openMenu).as((m) => m === name)}
        >
          {content}
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

    // ==================================================================
    // =======================  DASHBOARD  ==============================
    // ==================================================================

    // ---------- hero: big clock + date ----------
    function DashboardHero() {
      const time = Variable("").poll(
        1000,
        () => GLib.DateTime.new_now_local().format("%H:%M")!,
      )
      const date = Variable("").poll(
        60_000,
        () => GLib.DateTime.new_now_local().format("%A, %d %B %Y")!,
      )
      return (
        <box vertical className="dash-hero" halign={Gtk.Align.CENTER}>
          <label className="dash-hero-time" label={bind(time)} />
          <label className="dash-hero-date" label={bind(date)} />
        </box>
      )
    }

    // ---------- calendar ----------
    type CalData = {
      label: string
      today: number
      cells: (number | null)[]
    }

    function getCalendarData(): CalData {
      const now = GLib.DateTime.new_now_local()
      const year = now.get_year()
      const month = now.get_month()
      const today = now.get_day_of_month()
      const first = GLib.DateTime.new_local(year, month, 1, 0, 0, 0)!
      const daysInMonth = first.get_days_in_month()
      // get_day_of_week: Monday = 1, Sunday = 7
      const firstWeekday = first.get_day_of_week()
      const cells: (number | null)[] = []
      for (let i = 1; i < firstWeekday; i++) cells.push(null)
      for (let d = 1; d <= daysInMonth; d++) cells.push(d)
      while (cells.length < 42) cells.push(null)
      return { label: now.format("%B %Y")!, today, cells }
    }

    function DashboardCalendar() {
      const data = Variable<CalData>(getCalendarData()).poll(
        60_000,
        () => getCalendarData(),
      )
      const weekdays = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
      return (
        <box vertical className="dash-card" widthRequest={320}>
          <label className="dash-card-title" xalign={0} label={bind(data).as((d) => d.label)} />
          <grid columnHomogeneous rowHomogeneous columnSpacing={4} rowSpacing={4}>
            {weekdays.map((d) => (
              <label className="dash-cal-header" label={d} xalign={0.5} hexpand />
            ))}
            {bind(data).as((d) =>
              d.cells.map((cell, i) => {
                if (cell === null) return <label label="" xalign={0.5} />
                const isWeekend = (i % 7) >= 5
                const isToday = cell === d.today
                if (isToday)
                  return (
                    <box className="dash-cal-today" halign={Gtk.Align.FILL} valign={Gtk.Align.FILL}>
                      <label label={String(cell)} xalign={0.5} hexpand />
                    </box>
                  )
                return (
                  <label
                    className={isWeekend ? "dash-cal-weekend" : "dash-cal-day"}
                    label={String(cell)}
                    xalign={0.5}
                    hexpand
                  />
                )
              }),
            )}
          </grid>
        </box>
      )
    }

    // ---------- system stats ----------
    type SysStats = {
      cpu: number
      gpu: number | null
      ram: number
      disks: { label: string; pct: number | null }[]
    }

    function syncExec(cmdline: string): string | null {
      try {
        const [ok, stdout, , status] = GLib.spawn_command_line_sync(cmdline)
        if (!ok || status !== 0) return null
        return new TextDecoder().decode(stdout).trim()
      } catch (_e) {
        return null
      }
    }

    function readFileContents(path: string): string | null {
      try {
        const [ok, contents] = GLib.file_get_contents(path)
        if (!ok) return null
        return new TextDecoder().decode(contents)
      } catch (_e) {
        return null
      }
    }

    // parse /proc/stat line "cpu  u n s idle iowait irq softirq steal ..."
    function parseCpuLine(text: string) {
      const line = text.split("\n").find((l) => l.startsWith("cpu "))
      if (!line) return null
      const parts = line.trim().split(/\s+/).slice(1).map(Number)
      if (parts.length < 5) return null
      const total = parts.reduce((a, b) => a + b, 0)
      const idle = parts[3] + (parts[4] || 0)
      return { total, idle }
    }

    let lastCpu: { total: number; idle: number } | null = null

    function pollCpu(): number {
      const text = readFileContents("/proc/stat")
      if (!text) return 0
      const cur = parseCpuLine(text)
      if (!cur) return 0
      if (!lastCpu) { lastCpu = cur; return 0 }
      const totalDelta = cur.total - lastCpu.total
      const idleDelta = cur.idle - lastCpu.idle
      const pct = totalDelta > 0 ? Math.round((1 - idleDelta / totalDelta) * 100) : 0
      lastCpu = cur
      return Math.max(0, Math.min(100, pct))
    }

    function pollRam(): number {
      const text = readFileContents("/proc/meminfo")
      if (!text) return 0
      const total = parseInt(text.match(/MemTotal:\s+(\d+)/)?.[1] || "0")
      const avail = parseInt(text.match(/MemAvailable:\s+(\d+)/)?.[1] || "0")
      if (total === 0) return 0
      return Math.round(((total - avail) / total) * 100)
    }

    function pollGpu(): number | null {
      // NVIDIA first
      const nv = syncExec("nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits")
      if (nv) {
        const pct = parseInt(nv.split("\n")[0])
        if (!isNaN(pct)) return pct
      }
      // AMD/Intel sysfs
      const sys = readFileContents("/sys/class/drm/card0/device/gpu_busy_percent")
      if (sys) {
        const pct = parseInt(sys.trim())
        if (!isNaN(pct)) return pct
      }
      return null
    }

    function pollDisk(path: string): number | null {
      const out = syncExec("df -P " + path)
      if (!out) return null
      const lines = out.split("\n")
      if (lines.length < 2) return null
      const parts = lines[1].split(/\s+/)
      if (parts.length < 5) return null
      const pct = parseInt(parts[4].replace("%", ""))
      return isNaN(pct) ? null : pct
    }

    function collectSysStats(): SysStats {
      const home = GLib.get_home_dir()
      return {
        cpu: pollCpu(),
        gpu: pollGpu(),
        ram: pollRam(),
        disks: [
          { label: "/",   pct: pollDisk("/") },
          { label: "HDD", pct: pollDisk(home + "/HDD") },
          { label: "SSD", pct: pollDisk(home + "/SSD") },
        ],
      }
    }

    const sysStats = Variable<SysStats>({
      cpu: 0, gpu: null, ram: 0, disks: [],
    }).poll(3000, () => collectSysStats())

    function makeBar(pct: number, width: number = 10): string {
      const filled = Math.round((pct / 100) * width)
      return "▓".repeat(filled) + "░".repeat(width - filled)
    }

    function SysRow({ label, pct }: { label: string; pct: number | null }) {
      if (pct === null) {
        return (
          <box className="dash-sys-row" spacing={8}>
            <label className="dash-sys-label" label={label} xalign={0} />
            <label className="dash-sys-bar dim" label="░░░░░░░░░░" />
            <label className="dash-sys-value dim" label="—" xalign={1} hexpand />
          </box>
        )
      }
      const cls = pct > 95 ? "red" : pct > 80 ? "amber" : "moss"
      return (
        <box className="dash-sys-row" spacing={8}>
          <label className="dash-sys-label" label={label} xalign={0} />
          <label className={"dash-sys-bar " + cls} label={makeBar(pct)} />
          <label className={"dash-sys-value " + cls} label={pct + "%"} xalign={1} hexpand />
        </box>
      )
    }

    function DashboardSystem() {
      return (
        <box vertical className="dash-card" widthRequest={320}>
          <label className="dash-card-title" xalign={0} label="System" />
          {bind(sysStats).as((s) => (
            <box vertical spacing={4}>
              <SysRow label="CPU" pct={s.cpu} />
              {s.gpu !== null && <SysRow label="GPU" pct={s.gpu} />}
              <SysRow label="RAM" pct={s.ram} />
              <box vertical marginTop={8} spacing={4}>
                {s.disks.map((d) => (
                  <SysRow label={d.label} pct={d.pct} />
                ))}
              </box>
            </box>
          ))}
        </box>
      )
    }

    // ---------- session buttons ----------
    const dashArmed = Variable<string>("")

    function DashRow(id: string, icon: string, text: string, cmd: string[], confirm: boolean) {
      return (
        <button
          className={bind(dashArmed).as((a) => (a === id ? "dash-btn danger" : "dash-btn"))}
          onClicked={() => {
            if (confirm && dashArmed.get() !== id) {
              dashArmed.set(id)
              timeout(3000, () => {
                if (dashArmed.get() === id) dashArmed.set("")
              })
              return
            }
            dashArmed.set("")
            execAsync(cmd).catch(console.error)
          }}
        >
          <box>
            <label className="icon" label={icon} />
            <label
              xalign={0}
              hexpand
              label={bind(dashArmed).as((a) => (a === id ? "Click again to confirm" : text))}
            />
          </box>
        </button>
      )
    }

    function DashboardSession() {
      return (
        <box vertical className="dash-card" widthRequest={320}>
          <label className="dash-card-title" xalign={0} label="Session" />
          {DashRow("poweroff", I.power, "Shut down", ["systemctl", "poweroff"], true)}
          {DashRow("logout", I.logout, "Log out", ["niri", "msg", "action", "quit", "--skip-confirmation"], true)}
          {DashRow("lock", I.lock, "Lock", ["swaylock", "-f"], false)}
          {DashRow("suspend", I.suspend, "Suspend", ["systemctl", "suspend"], false)}
          {DashRow("reboot", I.reboot, "Reboot", ["systemctl", "reboot"], true)}
        </box>
      )
    }

    // ---------- dashboard window ----------
    function Dashboard(gdkmonitor: Gdk.Monitor) {
      const { TOP, BOTTOM, LEFT, RIGHT } = Astal.WindowAnchor
      return (
        <window
          className="Dashboard"
          namespace="dashboard"
          gdkmonitor={gdkmonitor}
          application={App}
          layer={Astal.Layer.BACKGROUND}
          exclusivity={Astal.Exclusivity.IGNORE}
          keymode={Astal.Keymode.NONE}
          anchor={TOP | BOTTOM | LEFT | RIGHT}
          visible={bind(firstWorkspace)}
        >
          <box
            vertical
            className="dash-root"
            halign={Gtk.Align.CENTER}
            valign={Gtk.Align.CENTER}
            spacing={48}
          >
            <DashboardHero />
            <box homogeneous halign={Gtk.Align.CENTER} spacing={0} valign={Gtk.Align.START}>
              <DashboardCalendar />
              <DashboardSystem />
              <DashboardSession />
            </box>
          </box>
        </window>
      )
    }

    App.start({
      css: style,
      main() {
        startNiri()
        App.get_monitors().map(Bar)
        App.get_monitors().map(Dashboard)
        Scrim()
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

    window.Bar, window.Menu, window.Scrim {
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

    .battery.charging .icon { color: ${c.leaf}; }
    .battery.low { color: ${c.amber}; }
    .battery.low .icon { color: ${c.amber}; }
    .battery.critical { color: ${c.red}; }
    .battery.critical .icon { color: ${c.red}; }

    .power .icon { color: ${c.red}; }

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

    .fm-box {
      background: ${c.bg};
      border: 1px solid ${c.border};
      border-radius: 14px;
      padding: 12px;
      min-width: 320px;
    }

    .fm-box.power { min-width: 240px; }

    .fm-head, .fm-row { margin-bottom: 6px; }
    .fm-title { color: ${c.leaf}; font-weight: bold; font-size: 14px; }
    .fm-sub { color: ${c.dim}; margin-top: 8px; margin-bottom: 2px; }
    .fm-val { color: ${c.dim}; margin-left: 10px; }

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

    /* ================================================================
       DASHBOARD
       ================================================================ */

    window.Dashboard { background: transparent; color: ${c.fg}; }

    .dash-root {
      padding-top: 60px;
      padding-bottom: 32px;
    }

    .dash-hero { spacing: 4px; }
    .dash-hero-time {
      font-size: 110px;
      font-weight: bold;
      color: ${c.leaf};
      letter-spacing: 2px;
    }
    .dash-hero-date {
      font-size: 20px;
      color: ${c.dim};
      letter-spacing: 2px;
    }

    .dash-card {
      background: ${c.bg};
      border: 1px solid ${c.border};
      border-radius: 14px;
      padding: 16px 20px;
      margin: 6px;
      min-height: 260px;
    }

    .dash-card-title {
      color: ${c.leaf};
      font-weight: bold;
      font-size: 14px;
      margin-bottom: 12px;
    }

    /* calendar */
    .dash-cal-header {
      color: ${c.dim};
      font-size: 11px;
      padding-bottom: 4px;
    }
    .dash-cal-day { color: ${c.fg}; padding: 2px 0; }
    .dash-cal-weekend { color: ${c.dim}; padding: 2px 0; }
    .dash-cal-today {
      background: ${c.pill};
      border-radius: 6px;
    }
    .dash-cal-today label {
      color: ${c.leaf};
      font-weight: bold;
    }

    /* system */
    .dash-sys-row { margin-bottom: 6px; }
    .dash-sys-label {
      color: ${c.dim};
      min-width: 44px;
      font-size: 12px;
    }
    .dash-sys-bar {
      font-size: 12px;
      letter-spacing: -1px;
    }
    .dash-sys-bar.moss, .dash-sys-value.moss { color: ${c.moss}; }
    .dash-sys-bar.amber, .dash-sys-value.amber { color: ${c.amber}; }
    .dash-sys-bar.red, .dash-sys-value.red { color: ${c.red}; }
    .dash-sys-bar.dim, .dash-sys-value.dim { color: ${c.dim}; }
    .dash-sys-value {
      font-size: 12px;
      font-weight: bold;
      min-width: 40px;
    }

    /* session buttons */
    .dash-btn {
      background: ${c.pill};
      color: ${c.fg};
      border: none;
      box-shadow: none;
      border-radius: 10px;
      padding: 8px 12px;
      margin: 3px 0;
    }
    .dash-btn:hover { background: rgba(127, 176, 105, 0.25); }
    .dash-btn .icon {
      color: ${c.moss};
      margin-right: 12px;
      font-size: 15px;
    }
    .dash-btn.danger {
      background: rgba(201, 82, 74, 0.25);
      color: ${c.red};
    }
    .dash-btn.danger .icon { color: ${c.red}; }
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
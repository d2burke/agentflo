import { useState, useEffect, useCallback } from "react";

const C = {
  red: "#C8102E", redHover: "#A00D24", redLight: "#FDE8EC",
  redGlow: "rgba(200, 16, 46, 0.15)",
  navy: "#0A1628", navyLight: "#12203A", navyMid: "#1A2D4D",
  slate: "#64748B", slateLight: "#94A3B8",
  border: "#E2E8F0", borderLight: "#F1F5F9", bg: "#F8FAFC", white: "#FFFFFF",
  green: "#16A34A", greenLight: "#DCFCE7",
  amber: "#D97706", amberLight: "#FEF3C7",
  blue: "#2563EB", blueLight: "#DBEAFE",
  errorRed: "#DC2626", errorBg: "#FEE2E2",
};

const TASKS = [
  { id: 1, type: "Photography", address: "4521 Riverside Dr, Austin TX", price: 150, status: "posted", time: "Tomorrow, 2:00 PM", runner: null, desc: "Full interior and exterior photography for 3BR/2BA listing." },
  { id: 2, type: "Showing", address: "812 Congress Ave #4B, Austin TX", price: 75, status: "in_progress", time: "Today, 4:30 PM", runner: "Maria Santos", desc: "Buyer is pre-approved. Highlight backyard and updated kitchen." },
  { id: 3, type: "Photography", address: "1100 S Lamar Blvd, Austin TX", price: 200, status: "completed", time: "Yesterday", runner: "James Chen", desc: "HDR photos of all rooms including closets. Twilight exterior required." },
  { id: 4, type: "Staging", address: "2200 Barton Springs Rd, Austin TX", price: 350, status: "in_progress", time: "Mar 2, 10:00 AM", runner: "Ashley Park", desc: "Focus on living room and master bedroom. Neutral tones preferred." },
  { id: 5, type: "Showing", address: "567 E 6th St, Austin TX", price: 60, status: "posted", time: "Mar 3, 1:00 PM", runner: null, desc: "Open house for a downtown condo." },
  { id: 10, type: "Photography", address: "700 Lavaca St, Austin TX", price: 175, status: "completed", time: "Feb 20", runner: "James Chen", desc: "Standard listing photos." },
  { id: 11, type: "Staging", address: "3100 Guadalupe St, Austin TX", price: 300, status: "completed", time: "Feb 18", runner: "Ashley Park", desc: "Full staging with rented furniture." },
];

const AVAILABLE = [
  { id: 6, type: "Photography", address: "900 W 5th St, Austin TX", price: 175, agent: "Sarah Mitchell", posted: "2h ago", distance: "3.2 mi", desc: "Luxury condo photography. Must have wide-angle lens." },
  { id: 7, type: "Showing", address: "1450 S Congress Ave, Austin TX", price: 80, agent: "Tom Bradley", posted: "45m ago", distance: "1.8 mi", desc: "First-time buyer showing. Walk through property." },
  { id: 8, type: "Photography", address: "3300 Bee Cave Rd, Austin TX", price: 225, agent: "Lisa Wong", posted: "4h ago", distance: "7.1 mi", desc: "Hill country estate. Drone shots required." },
  { id: 9, type: "Staging", address: "2100 E Riverside Dr, Austin TX", price: 400, agent: "Mike Johnson", posted: "1h ago", distance: "4.5 mi", desc: "Modern apartment staging. Furniture delivery at 9 AM." },
];

const CHAT_MSGS = [
  { id: 1, from: "runner", text: "Hi! Quick question — is there a lockbox or will I need keys?", time: "2:15 PM" },
  { id: 2, from: "agent", text: "Lockbox! Code will be shared 1 hour before.", time: "2:18 PM" },
  { id: 3, from: "runner", text: "Should I prepare comp sheets for the buyers?", time: "2:20 PM" },
  { id: 4, from: "agent", text: "Yes please! I'll upload the latest comps to the task.", time: "2:22 PM" },
  { id: 5, from: "runner", text: "Got it — I'll have everything ready!", time: "2:25 PM" },
];

const NOTIFS = [
  { id: 1, title: "Task Accepted", message: "Maria Santos accepted your showing at 812 Congress Ave", time: "2h ago", read: false, iconName: "check", taskId: 2 },
  { id: 2, title: "Deliverables Ready", message: "James Chen submitted photos for 1100 S Lamar Blvd", time: "Yesterday", read: false, iconName: "camera", taskId: 3 },
  { id: 3, title: "Payment Processed", message: "$200 released for photography at 1100 S Lamar", time: "Yesterday", read: true, iconName: "dollar", taskId: 3 },
  { id: 4, title: "New Message", message: "Ashley Park: 'Quick question about the staging setup'", time: "2 days ago", read: true, iconName: "send", taskId: 4, isMessage: true },
];

const RUNNER_HISTORY = [
  { id: 101, type: "Photography", address: "1100 S Lamar Blvd, Austin TX", price: 200, status: "completed", time: "Yesterday", agent: "Daniel Martinez", desc: "HDR photos." },
  { id: 102, type: "Showing", address: "500 W 2nd St, Austin TX", price: 75, status: "completed", time: "Feb 25", agent: "Sarah Mitchell", desc: "Buyer showing." },
];

const Icon = ({ name, size = 20, color = C.slate }) => {
  const s = { width: size, height: size, display: "inline-flex", alignItems: "center", justifyContent: "center" };
  const p = { viewBox: "0 0 24 24", fill: "none", stroke: color, strokeWidth: "2", strokeLinecap: "round", strokeLinejoin: "round" };
  const icons = {
    home: <svg style={s} {...p}><path d="M3 9l9-7 9 7v11a2 2 0 01-2 2H5a2 2 0 01-2-2z"/><polyline points="9 22 9 12 15 12 15 22"/></svg>,
    bell: <svg style={s} {...p}><path d="M18 8A6 6 0 006 8c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.73 21a2 2 0 01-3.46 0"/></svg>,
    user: <svg style={s} {...p}><path d="M20 21v-2a4 4 0 00-4-4H8a4 4 0 00-4 4v2"/><circle cx="12" cy="7" r="4"/></svg>,
    plus: <svg style={s} {...p}><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg>,
    camera: <svg style={s} {...p}><path d="M23 19a2 2 0 01-2 2H3a2 2 0 01-2-2V8a2 2 0 012-2h4l2-3h6l2 3h4a2 2 0 012 2z"/><circle cx="12" cy="13" r="4"/></svg>,
    eye: <svg style={s} {...p}><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/></svg>,
    box: <svg style={s} {...p}><path d="M21 16V8a2 2 0 00-1-1.73l-7-4a2 2 0 00-2 0l-7 4A2 2 0 003 8v8a2 2 0 001 1.73l7 4a2 2 0 002 0l7-4A2 2 0 0021 16z"/></svg>,
    chevron: <svg style={s} {...p}><polyline points="9 18 15 12 9 6"/></svg>,
    back: <svg style={s} {...p}><polyline points="15 18 9 12 15 6"/></svg>,
    x: <svg style={s} {...p}><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>,
    check: <svg style={s} {...p}><polyline points="20 6 9 17 4 12"/></svg>,
    map: <svg style={s} {...p}><path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0118 0z"/><circle cx="12" cy="10" r="3"/></svg>,
    clock: <svg style={s} {...p}><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>,
    dollar: <svg style={s} {...p}><line x1="12" y1="1" x2="12" y2="23"/><path d="M17 5H9.5a3.5 3.5 0 000 7h5a3.5 3.5 0 010 7H6"/></svg>,
    star: <svg style={s} viewBox="0 0 24 24" fill={color} stroke={color} strokeWidth="1"><polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/></svg>,
    search: <svg style={s} {...p}><circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/></svg>,
    send: <svg style={s} {...p}><line x1="22" y1="2" x2="11" y2="13"/><polygon points="22 2 15 22 11 13 2 9 22 2"/></svg>,
    refresh: <svg style={s} {...p}><polyline points="23 4 23 10 17 10"/><polyline points="1 20 1 14 7 14"/><path d="M3.51 9a9 9 0 0114.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0020.49 15"/></svg>,
    creditcard: <svg style={s} {...p}><rect x="1" y="4" width="22" height="16" rx="2" ry="2"/><line x1="1" y1="10" x2="23" y2="10"/></svg>,
    shield: <svg style={s} {...p}><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg>,
    mail: <svg style={s} {...p}><path d="M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z"/><polyline points="22 6 12 13 2 6"/></svg>,
    phone: <svg style={s} {...p}><path d="M22 16.92v3a2 2 0 01-2.18 2 19.79 19.79 0 01-8.63-3.07 19.5 19.5 0 01-6-6 19.79 19.79 0 01-3.07-8.67A2 2 0 014.11 2h3a2 2 0 012 1.72c.127.96.361 1.903.7 2.81a2 2 0 01-.45 2.11L8.09 9.91a16 16 0 006 6l1.27-1.27a2 2 0 012.11-.45c.907.339 1.85.573 2.81.7A2 2 0 0122 16.92z"/></svg>,
    building: <svg style={s} {...p}><rect x="4" y="2" width="16" height="20" rx="2" ry="2"/><line x1="9" y1="6" x2="9" y2="6.01"/><line x1="15" y1="6" x2="15" y2="6.01"/><line x1="9" y1="10" x2="9" y2="10.01"/><line x1="15" y1="10" x2="15" y2="10.01"/><line x1="9" y1="14" x2="9" y2="14.01"/><line x1="15" y1="14" x2="15" y2="14.01"/><line x1="9" y1="18" x2="15" y2="18"/></svg>,
    mappin: <svg style={s} {...p}><path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0118 0z"/><circle cx="12" cy="10" r="3"/></svg>,
    calendar: <svg style={s} {...p}><rect x="3" y="4" width="18" height="18" rx="2" ry="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/></svg>,
    filetext: <svg style={s} {...p}><path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="16" y1="13" x2="8" y2="13"/><line x1="16" y1="17" x2="8" y2="17"/></svg>,
    logout: <svg style={s} {...p}><path d="M9 21H5a2 2 0 01-2-2V5a2 2 0 012-2h4"/><polyline points="16 17 21 12 16 7"/><line x1="21" y1="12" x2="9" y2="12"/></svg>,
    trending: <svg style={s} {...p}><polyline points="23 6 13.5 15.5 8.5 10.5 1 18"/><polyline points="17 6 23 6 23 12"/></svg>,
    bank: <svg style={s} {...p}><line x1="12" y1="1" x2="12" y2="23"/><path d="M17 5H9.5a3.5 3.5 0 000 7h5a3.5 3.5 0 010 7H6"/></svg>,
    download: <svg style={s} {...p}><path d="M21 15v4a2 2 0 01-2 2H5a2 2 0 01-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg>,
    edit: <svg style={s} {...p}><path d="M11 4H4a2 2 0 00-2 2v14a2 2 0 002 2h14a2 2 0 002-2v-7"/><path d="M18.5 2.5a2.121 2.121 0 013 3L12 15l-4 1 1-4 9.5-9.5z"/></svg>,
    filter: <svg style={s} {...p}><polygon points="22 3 2 3 10 12.46 10 19 14 21 14 12.46 22 3"/></svg>,
    crosshair: <svg style={s} {...p}><circle cx="12" cy="12" r="10"/><line x1="22" y1="12" x2="18" y2="12"/><line x1="6" y1="12" x2="2" y2="12"/><line x1="12" y1="6" x2="12" y2="2"/><line x1="12" y1="22" x2="12" y2="18"/></svg>,
    message: <svg style={s} {...p}><path d="M21 15a2 2 0 01-2 2H7l-4 4V5a2 2 0 012-2h14a2 2 0 012 2z"/></svg>,
    image: <svg style={s} {...p}><rect x="3" y="3" width="18" height="18" rx="2" ry="2"/><circle cx="8.5" cy="8.5" r="1.5"/><polyline points="21 15 16 10 5 21"/></svg>,
    settings: <svg style={s} {...p}><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 00.33 1.82l.06.06a2 2 0 010 2.83 2 2 0 01-2.83 0l-.06-.06a1.65 1.65 0 00-1.82-.33 1.65 1.65 0 00-1 1.51V21a2 2 0 01-4 0v-.09A1.65 1.65 0 009 19.4a1.65 1.65 0 00-1.82.33l-.06.06a2 2 0 01-2.83-2.83l.06-.06A1.65 1.65 0 004.68 15a1.65 1.65 0 00-1.51-1H3a2 2 0 010-4h.09A1.65 1.65 0 004.6 9a1.65 1.65 0 00-.33-1.82l-.06-.06a2 2 0 012.83-2.83l.06.06A1.65 1.65 0 009 4.68a1.65 1.65 0 001-1.51V3a2 2 0 014 0v.09a1.65 1.65 0 001 1.51 1.65 1.65 0 001.82-.33l.06-.06a2 2 0 012.83 2.83l-.06.06A1.65 1.65 0 0019.4 9a1.65 1.65 0 001.51 1H21a2 2 0 010 4h-.09a1.65 1.65 0 00-1.51 1z"/></svg>,
    briefcase: <svg style={s} {...p}><rect x="2" y="7" width="20" height="14" rx="2" ry="2"/><path d="M16 21V5a2 2 0 00-2-2h-4a2 2 0 00-2 2v16"/></svg>,
  };
  return icons[name] || null;
};
const catIcon = t => t === "Photography" ? "camera" : t === "Showing" ? "eye" : "box";
const statusBadge = s => ({ posted: { l: "Posted", bg: C.blueLight, c: C.blue }, in_progress: { l: "In Progress", bg: C.amberLight, c: C.amber }, completed: { l: "Completed", bg: C.greenLight, c: C.green }, pending: { l: "Pending", bg: C.amberLight, c: C.amber }, draft: { l: "Draft", bg: C.borderLight, c: C.slate } })[s] || { l: s, bg: C.borderLight, c: C.slate };
const Btn = ({ children, variant = "primary", size = "md", onClick, style, full, disabled }) => { const base = { border: "none", borderRadius: 9999, cursor: disabled ? "not-allowed" : "pointer", fontWeight: 600, fontFamily: "'DM Sans',sans-serif", display: "inline-flex", alignItems: "center", justifyContent: "center", gap: 8, transition: "all 0.2s", width: full ? "100%" : "auto", opacity: disabled ? 0.5 : 1 }; const v = { primary: { background: C.red, color: "#fff", padding: size === "lg" ? "16px 28px" : "12px 20px", fontSize: size === "lg" ? 16 : 14 }, secondary: { background: C.white, color: C.navy, border: `1.5px solid ${C.border}`, padding: size === "lg" ? "16px 28px" : "12px 20px", fontSize: size === "lg" ? 16 : 14 }, ghost: { background: "transparent", color: C.slate, padding: "8px 12px", fontSize: 14 }, small: { background: C.redLight, color: C.red, padding: "6px 14px", fontSize: 13 } }; return <button style={{ ...base, ...v[variant], ...style }} onClick={disabled ? undefined : onClick}>{children}</button>; };
const Card = ({ children, style, onClick }) => <div onClick={onClick} style={{ background: C.white, borderRadius: 14, border: `1px solid ${C.border}`, padding: 20, cursor: onClick ? "pointer" : "default", ...style }}>{children}</div>;
const Badge = ({ l, bg, c }) => <span style={{ background: bg, color: c, fontSize: 12, fontWeight: 600, padding: "4px 10px", borderRadius: 20, letterSpacing: 0.3 }}>{l}</span>;
const Avatar = ({ name, size = 36 }) => { const ini = name.split(" ").map(n => n[0]).join(""); return <div style={{ width: size, height: size, borderRadius: size / 2, background: C.navy, color: "#fff", display: "flex", alignItems: "center", justifyContent: "center", fontSize: size * 0.38, fontWeight: 700, flexShrink: 0 }}>{ini}</div>; };
const ProgressBar = ({ value, max = 100, dark }) => <div style={{ height: 6, background: dark ? "rgba(255,255,255,0.15)" : C.borderLight, borderRadius: 3, overflow: "hidden" }}><div style={{ height: "100%", width: `${(value / max) * 100}%`, background: C.red, borderRadius: 3, transition: "width 0.5s" }} /></div>;
const FieldRow = ({ label, value, icon }) => (<div style={{ padding: "14px 0", borderBottom: `1px solid ${C.borderLight}` }}><div style={{ display: "flex", alignItems: "center", gap: 10 }}>{icon && <Icon name={icon} size={16} color={C.slateLight} />}<div style={{ flex: 1 }}><p style={{ margin: 0, fontSize: 12, color: C.slateLight, fontWeight: 500 }}>{label}</p><p style={{ margin: "2px 0 0", fontSize: 15, color: C.navy, fontWeight: 500 }}>{value}</p></div><Icon name="chevron" size={14} color={C.borderLight} /></div></div>);
const ToggleRow = ({ label, desc, on, onToggle }) => (<div onClick={onToggle} style={{ display: "flex", alignItems: "center", justifyContent: "space-between", padding: "14px 0", borderBottom: `1px solid ${C.borderLight}`, cursor: "pointer" }}><div style={{ flex: 1, marginRight: 12 }}><p style={{ margin: 0, fontSize: 14, fontWeight: 500, color: C.navy }}>{label}</p>{desc && <p style={{ margin: "2px 0 0", fontSize: 12, color: C.slateLight }}>{desc}</p>}</div><div style={{ width: 48, height: 28, borderRadius: 14, background: on ? C.green : C.border, display: "flex", alignItems: "center", padding: 2, flexShrink: 0 }}><div style={{ width: 24, height: 24, borderRadius: 12, background: "#fff", boxShadow: "0 1px 3px rgba(0,0,0,0.15)", transform: on ? "translateX(20px)" : "translateX(0)", transition: "transform 0.2s" }} /></div></div>);
const MenuRow = ({ icon, label, onClick, last }) => (<div onClick={onClick} style={{ display: "flex", alignItems: "center", justifyContent: "space-between", padding: "14px 0", borderBottom: last ? "none" : `1px solid ${C.borderLight}`, cursor: "pointer" }}><div style={{ display: "flex", alignItems: "center", gap: 12 }}><Icon name={icon} size={18} color={C.slate} /><span style={{ fontSize: 14, fontWeight: 500, color: C.navy }}>{label}</span></div><Icon name="chevron" size={16} color={C.slateLight} /></div>);
const SectionHead = ({ title, action, onAction, right }) => (<div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 12 }}><h3 style={{ margin: 0, fontSize: 17, fontWeight: 700, color: C.navy }}>{title}</h3><div style={{ display: "flex", alignItems: "center", gap: 10 }}>{action && <span onClick={onAction} style={{ fontSize: 13, color: C.red, fontWeight: 600, cursor: "pointer" }}>{action}</span>}{right}</div></div>);
const TaskCard = ({ task, onClick, showRunner, showAgent }) => { const b = statusBadge(task.status); return (<Card onClick={onClick} style={{ padding: 16 }}><div style={{ display: "flex", gap: 14, alignItems: "flex-start" }}><div style={{ width: 42, height: 42, borderRadius: 12, background: C.redLight, display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0 }}><Icon name={catIcon(task.type)} size={20} color={C.red} /></div><div style={{ flex: 1, minWidth: 0 }}><div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 4 }}><span style={{ fontWeight: 700, fontSize: 15, color: C.navy }}>{task.type}</span>{task.status && <Badge {...b} />}{!task.status && <span style={{ fontSize: 17, fontWeight: 800, color: C.red }}>${task.price}</span>}</div><p style={{ margin: 0, fontSize: 13, color: C.slate, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{task.address}</p><div style={{ display: "flex", justifyContent: "space-between", marginTop: 8 }}><span style={{ fontSize: 13, color: C.slateLight }}>{showAgent && task.agent ? `Agent: ${task.agent}` : showRunner && task.runner ? `Runner: ${task.runner}` : task.time}</span><span style={{ fontSize: 15, fontWeight: 700, color: C.navy }}>${task.price}</span></div></div></div></Card>); };
const PhoneFrame = ({ children, title, onBack, rightAction, hideNav }) => (<div style={{ width: 390, height: 844, background: C.bg, borderRadius: 44, border: `8px solid ${C.navy}`, overflow: "hidden", display: "flex", flexDirection: "column", position: "relative", boxShadow: `0 25px 80px rgba(10,22,40,0.25), 0 0 0 1px rgba(10,22,40,0.08)`, fontFamily: "'DM Sans',sans-serif" }}>{!hideNav && <div style={{ height: 54, background: C.white, display: "flex", alignItems: "flex-end", justifyContent: "center", padding: "0 24px 8px", position: "relative", flexShrink: 0, zIndex: 10 }}><div style={{ width: 126, height: 34, background: C.navy, borderRadius: 20, position: "absolute", top: 0 }} />{onBack && <div onClick={onBack} style={{ position: "absolute", left: 16, bottom: 6, cursor: "pointer", padding: 4 }}><Icon name="back" color={C.red} size={22} /></div>}{title && <span style={{ fontSize: 17, fontWeight: 700, color: C.navy }}>{title}</span>}{rightAction && <div style={{ position: "absolute", right: 16, bottom: 6 }}>{rightAction}</div>}</div>}{hideNav && <div style={{ height: 34, flexShrink: 0, position: "relative" }}><div style={{ width: 126, height: 34, background: C.navy, borderRadius: 20, position: "absolute", top: 0, left: "50%", transform: "translateX(-50%)" }} /></div>}<div style={{ flex: 1, overflow: "auto", position: "relative" }}><div style={{ paddingBottom: hideNav ? 0 : 100 }}>{children}</div></div></div>);
const GlassTabBar = ({ activeTab, onTabChange, notifCount = 0 }) => (<div style={{ position: "absolute", bottom: 16, left: 0, right: 0, zIndex: 20, display: "flex", alignItems: "center", justifyContent: "center" }}><div style={{ display: "flex", alignItems: "center", padding: "5px", borderRadius: 26, background: "linear-gradient(180deg, rgba(255,255,255,0.75) 0%, rgba(245,247,250,0.6) 100%)", backdropFilter: "blur(40px) saturate(1.8)", WebkitBackdropFilter: "blur(40px) saturate(1.8)", boxShadow: "0 0.5px 0 0 rgba(255,255,255,0.7) inset, 0 -0.5px 0 0 rgba(0,0,0,0.03) inset, 0 8px 32px rgba(10,22,40,0.12)", border: "0.5px solid rgba(255,255,255,0.55)" }}>{[{ id: "Dashboard", icon: "home", label: "Home" }, { id: "Notifications", icon: "bell", label: "Notifications" }, { id: "Profile", icon: "user", label: "Profile" }].map(tab => { const active = activeTab === tab.id; return (<div key={tab.id} onClick={() => onTabChange(tab.id)} style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 2, padding: active ? "8px 18px" : "8px 14px", cursor: "pointer", borderRadius: 22, transition: "all 0.35s cubic-bezier(0.32,0.72,0,1)", background: active ? "rgba(200,16,46,0.1)" : "transparent" }}><div style={{ position: "relative" }}><Icon name={tab.icon} size={21} color={active ? C.red : "rgba(10,22,40,0.5)"} />{tab.id === "Notifications" && notifCount > 0 && <div style={{ position: "absolute", top: -5, right: -9, width: 15, height: 15, borderRadius: 8, background: C.red, color: "#fff", fontSize: 9, fontWeight: 700, display: "flex", alignItems: "center", justifyContent: "center", border: "2px solid rgba(255,255,255,0.85)" }}>{notifCount}</div>}</div>{active && <span style={{ fontSize: 10, fontWeight: 700, color: C.red }}>{tab.label}</span>}</div>); })}</div></div>);
const SheetModal = ({ children, onClose }) => (<div style={{ position: "absolute", inset: 0, zIndex: 50, display: "flex", flexDirection: "column", justifyContent: "flex-end" }}><div onClick={onClose} style={{ position: "absolute", inset: 0, background: "rgba(10,22,40,0.45)", backdropFilter: "blur(4px)" }} /><div style={{ position: "relative", background: C.white, borderRadius: "20px 20px 0 0", maxHeight: "92%", overflow: "auto", boxShadow: "0 -8px 40px rgba(10,22,40,0.18)", animation: "sheetUp 0.35s cubic-bezier(0.32,0.72,0,1)" }}><div style={{ display: "flex", justifyContent: "center", padding: "10px 0 0" }}><div style={{ width: 36, height: 5, borderRadius: 3, background: C.border }} /></div>{children}</div><style>{`@keyframes sheetUp{from{transform:translateY(100%)}to{transform:translateY(0)}}`}</style></div>);

const OnboardingFlow = ({ onComplete, onLogin }) => {
  const [step, setStep] = useState("landing"); // landing, role, signup, password, verify, welcome
  const [role, setRole] = useState(null);
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [showPw, setShowPw] = useState(false);
  const [otp, setOtp] = useState(["","","","","",""]);
  const [animKey, setAnimKey] = useState(0);
  const advance = (next) => { setAnimKey(k => k+1); setStep(next); };
  const agentProps = [
    { icon: "plus", title: "Post Tasks in Seconds", desc: "Photography, showings, staging — describe what you need and set your price." },
    { icon: "check", title: "Vetted Runners Only", desc: "Every task runner is a licensed real estate professional, verified on the platform." },
    { icon: "shield", title: "Secure Payments", desc: "Funds are held in escrow until you approve the work. Pay with confidence." },
  ];
  const runnerProps = [
    { icon: "dollar", title: "Earn on Your Schedule", desc: "Pick up tasks that fit your availability and specialties. Get paid weekly." },
    { icon: "map", title: "Tasks Near You", desc: "See available tasks in your service areas with real-time distance and payout info." },
    { icon: "trending", title: "Build Your Reputation", desc: "Earn ratings and unlock priority access to higher-paying tasks over time." },
  ];
  const slideIn = { animation: "slideIn 0.35s cubic-bezier(0.32,0.72,0,1)" };

  // Landing
  if (step === "landing") return (
    <div style={{ minHeight: 756, display: "flex", flexDirection: "column", alignItems: "center", background: C.white, padding: "0 40px" }}>
      <div style={{ flex: 1, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 12 }}>
        <div style={{ width: 72, height: 72, borderRadius: 20, background: C.red, display: "flex", alignItems: "center", justifyContent: "center", boxShadow: "0 12px 32px rgba(200,16,46,0.3)" }}><span style={{ color: "#fff", fontWeight: 800, fontSize: 36 }}>A</span></div>
        <h1 style={{ margin: 0, fontSize: 32, fontWeight: 800, color: C.navy, letterSpacing: -0.5 }}>Agent<span style={{ color: C.red }}>Assist</span></h1>
        <p style={{ margin: 0, fontSize: 15, color: C.slate }}>Delegate tasks. Close deals.</p>
      </div>
      <div style={{ width: "100%", paddingBottom: 32, display: "flex", flexDirection: "column", gap: 12 }}>
        <Btn variant="primary" size="lg" full onClick={() => { setRole("agent"); advance("signup"); }}>I'm a Real Estate Agent</Btn>
        <Btn variant="secondary" size="lg" full onClick={() => { setRole("runner"); advance("signup"); }}>I'm a Task Runner</Btn>
        <p onClick={onLogin} style={{ textAlign: "center", fontSize: 14, color: C.slate, marginTop: 8, cursor: "pointer" }}>Already have an account? <span style={{ color: C.red, fontWeight: 600 }}>Log In</span></p>
      </div>
      <style>{`@keyframes slideIn{from{opacity:0;transform:translateX(40px)}to{opacity:1;transform:translateX(0)}}@keyframes spin{to{transform:rotate(360deg)}}`}</style>
    </div>
  );

  // Sign Up — Name & Email
  if (step === "signup") return (
    <div key={animKey} style={{ minHeight: 756, display: "flex", flexDirection: "column", background: C.white, padding: "0 24px", ...slideIn }}>
      <div style={{ padding: "20px 0 0" }}>
        <div onClick={() => advance("landing")} style={{ cursor: "pointer", padding: 4, display: "inline-flex" }}><Icon name="back" color={C.navy} size={22} /></div>
      </div>
      <div style={{ padding: "16px 0 24px" }}>
        <p style={{ margin: 0, fontSize: 14, color: C.red, fontWeight: 600 }}>Step 1 of 3</p>
        <h1 style={{ margin: "4px 0 0", fontSize: 26, fontWeight: 800, color: C.navy }}>Create your account</h1>
        <p style={{ margin: "6px 0 0", fontSize: 14, color: C.slate }}>Let's start with the basics.</p>
      </div>
      <div style={{ display: "flex", gap: 4, marginBottom: 28 }}>{[1,2,3].map(i => <div key={i} style={{ flex: 1, height: 4, borderRadius: 2, background: i === 1 ? C.red : C.borderLight }} />)}</div>
      <div style={{ display: "flex", flexDirection: "column", gap: 18, flex: 1 }}>
        <div>
          <label style={{ fontSize: 13, fontWeight: 600, color: C.navy, display: "block", marginBottom: 6 }}>Full Name</label>
          <input type="text" value={name} onChange={e => setName(e.target.value)} placeholder="Your full name" style={{ width: "100%", padding: "14px 16px", border: `1.5px solid ${C.border}`, borderRadius: 12, fontSize: 15, fontFamily: "'DM Sans',sans-serif", outline: "none", boxSizing: "border-box", background: C.white, color: C.navy }} />
        </div>
        <div>
          <label style={{ fontSize: 13, fontWeight: 600, color: C.navy, display: "block", marginBottom: 6 }}>Email Address</label>
          <input type="email" value={email} onChange={e => setEmail(e.target.value)} placeholder="you@example.com" style={{ width: "100%", padding: "14px 16px", border: `1.5px solid ${C.border}`, borderRadius: 12, fontSize: 15, fontFamily: "'DM Sans',sans-serif", outline: "none", boxSizing: "border-box", background: C.white, color: C.navy }} />
        </div>
        <div>
          <label style={{ fontSize: 13, fontWeight: 600, color: C.navy, display: "block", marginBottom: 6 }}>Phone Number</label>
          <input type="tel" placeholder="(512) 555-0000" style={{ width: "100%", padding: "14px 16px", border: `1.5px solid ${C.border}`, borderRadius: 12, fontSize: 15, fontFamily: "'DM Sans',sans-serif", outline: "none", boxSizing: "border-box", background: C.white, color: C.navy }} />
        </div>
      </div>
      <div style={{ paddingBottom: 40 }}>
        <Btn variant="primary" size="lg" full onClick={() => advance("password")}>Continue</Btn>
        <p style={{ textAlign: "center", fontSize: 12, color: C.slateLight, marginTop: 12, lineHeight: 1.5 }}>By continuing, you agree to our <span style={{ color: C.red }}>Terms of Service</span> and <span style={{ color: C.red }}>Privacy Policy</span></p>
      </div>
    </div>
  );

  // Password
  if (step === "password") return (
    <div key={animKey} style={{ minHeight: 756, display: "flex", flexDirection: "column", background: C.white, padding: "0 24px", ...slideIn }}>
      <div style={{ padding: "20px 0 0" }}>
        <div onClick={() => advance("signup")} style={{ cursor: "pointer", padding: 4, display: "inline-flex" }}><Icon name="back" color={C.navy} size={22} /></div>
      </div>
      <div style={{ padding: "16px 0 24px" }}>
        <p style={{ margin: 0, fontSize: 14, color: C.red, fontWeight: 600 }}>Step 2 of 3</p>
        <h1 style={{ margin: "4px 0 0", fontSize: 26, fontWeight: 800, color: C.navy }}>Set your password</h1>
        <p style={{ margin: "6px 0 0", fontSize: 14, color: C.slate }}>Choose a strong password to secure your account.</p>
      </div>
      <div style={{ display: "flex", gap: 4, marginBottom: 28 }}>{[1,2,3].map(i => <div key={i} style={{ flex: 1, height: 4, borderRadius: 2, background: i <= 2 ? C.red : C.borderLight }} />)}</div>
      <div style={{ display: "flex", flexDirection: "column", gap: 18, flex: 1 }}>
        <div>
          <label style={{ fontSize: 13, fontWeight: 600, color: C.navy, display: "block", marginBottom: 6 }}>Password</label>
          <div style={{ position: "relative" }}>
            <input type={showPw ? "text" : "password"} placeholder="Minimum 8 characters" style={{ width: "100%", padding: "14px 48px 14px 16px", border: `1.5px solid ${C.border}`, borderRadius: 12, fontSize: 15, fontFamily: "'DM Sans',sans-serif", outline: "none", boxSizing: "border-box", background: C.white, color: C.navy }} />
            <div onClick={() => setShowPw(!showPw)} style={{ position: "absolute", right: 14, top: "50%", transform: "translateY(-50%)", cursor: "pointer" }}><Icon name="eye" size={18} color={C.slateLight} /></div>
          </div>
        </div>
        <div>
          <label style={{ fontSize: 13, fontWeight: 600, color: C.navy, display: "block", marginBottom: 6 }}>Confirm Password</label>
          <input type="password" placeholder="Re-enter your password" style={{ width: "100%", padding: "14px 16px", border: `1.5px solid ${C.border}`, borderRadius: 12, fontSize: 15, fontFamily: "'DM Sans',sans-serif", outline: "none", boxSizing: "border-box", background: C.white, color: C.navy }} />
        </div>
        <div style={{ display: "flex", flexDirection: "column", gap: 8, marginTop: 4 }}>
          {["At least 8 characters", "One uppercase letter", "One number or symbol"].map((r, i) => (
            <div key={i} style={{ display: "flex", alignItems: "center", gap: 8 }}>
              <div style={{ width: 18, height: 18, borderRadius: 9, background: C.borderLight, display: "flex", alignItems: "center", justifyContent: "center" }}><Icon name="check" size={11} color={C.slateLight} /></div>
              <span style={{ fontSize: 13, color: C.slateLight }}>{r}</span>
            </div>
          ))}
        </div>
      </div>
      <div style={{ paddingBottom: 40 }}>
        <Btn variant="primary" size="lg" full onClick={() => advance("verify")}>Create Account</Btn>
      </div>
    </div>
  );

  // Email Verification
  if (step === "verify") return (
    <div key={animKey} style={{ minHeight: 756, display: "flex", flexDirection: "column", background: C.white, padding: "0 24px", ...slideIn }}>
      <div style={{ padding: "20px 0 0" }}>
        <div onClick={() => advance("password")} style={{ cursor: "pointer", padding: 4, display: "inline-flex" }}><Icon name="back" color={C.navy} size={22} /></div>
      </div>
      <div style={{ padding: "16px 0 24px" }}>
        <p style={{ margin: 0, fontSize: 14, color: C.red, fontWeight: 600 }}>Step 3 of 3</p>
        <h1 style={{ margin: "4px 0 0", fontSize: 26, fontWeight: 800, color: C.navy }}>Verify your email</h1>
        <p style={{ margin: "6px 0 0", fontSize: 14, color: C.slate }}>We sent a 6-digit code to <strong style={{ color: C.navy }}>{email || "you@example.com"}</strong></p>
      </div>
      <div style={{ display: "flex", gap: 4, marginBottom: 28 }}>{[1,2,3].map(i => <div key={i} style={{ flex: 1, height: 4, borderRadius: 2, background: C.red }} />)}</div>
      <div style={{ display: "flex", gap: 10, justifyContent: "center", marginBottom: 24 }}>
        {[0,1,2,3,4,5].map(i => (
          <div key={i} style={{ width: 48, height: 56, borderRadius: 12, border: `2px solid ${i === 0 ? C.red : C.border}`, display: "flex", alignItems: "center", justifyContent: "center", fontSize: 24, fontWeight: 800, color: C.navy, background: C.white, boxShadow: i === 0 ? `0 0 0 3px ${C.redGlow}` : "none" }}>
            {i < 3 ? ["4","2","8"][i] : ""}
          </div>
        ))}
      </div>
      <div style={{ textAlign: "center", marginBottom: 32 }}>
        <p style={{ fontSize: 14, color: C.slateLight }}>Didn't receive a code? <span style={{ color: C.red, fontWeight: 600, cursor: "pointer" }}>Resend</span></p>
      </div>
      <div style={{ flex: 1 }} />
      <div style={{ paddingBottom: 40 }}>
        <Btn variant="primary" size="lg" full onClick={() => advance("welcome")}>Verify & Continue</Btn>
      </div>
    </div>
  );

  // Welcome — role-specific value props
  if (step === "welcome") {
    const props = role === "agent" ? agentProps : runnerProps;
    return (
      <div key={animKey} style={{ minHeight: 756, display: "flex", flexDirection: "column", background: C.white, padding: "0 24px", ...slideIn }}>
        <div style={{ padding: "32px 0 8px", textAlign: "center" }}>
          <div style={{ width: 56, height: 56, borderRadius: 16, background: C.redLight, display: "flex", alignItems: "center", justifyContent: "center", margin: "0 auto 16px" }}>
            <Icon name={role === "agent" ? "briefcase" : "trending"} size={28} color={C.red} />
          </div>
          <h1 style={{ margin: 0, fontSize: 26, fontWeight: 800, color: C.navy }}>Welcome{name ? `, ${name.split(" ")[0]}` : ""}!</h1>
          <p style={{ margin: "6px 0 0", fontSize: 15, color: C.slate }}>{role === "agent" ? "Here's how Agent Flo works for you" : "Here's what you can do as a Task Runner"}</p>
        </div>
        <div style={{ flex: 1, display: "flex", flexDirection: "column", gap: 16, paddingTop: 24 }}>
          {props.map((p, i) => (
            <div key={i} style={{ display: "flex", gap: 14, alignItems: "flex-start" }}>
              <div style={{ width: 44, height: 44, borderRadius: 12, background: C.redGlow, display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0 }}>
                <Icon name={p.icon} size={20} color={C.red} />
              </div>
              <div>
                <p style={{ margin: 0, fontSize: 15, fontWeight: 700, color: C.navy }}>{p.title}</p>
                <p style={{ margin: "4px 0 0", fontSize: 13, color: C.slate, lineHeight: 1.5 }}>{p.desc}</p>
              </div>
            </div>
          ))}
        </div>
        <div style={{ paddingBottom: 40 }}>
          <Btn variant="primary" size="lg" full onClick={() => role === "agent" ? advance("firsttask") : onComplete(role)}>{role === "agent" ? "Post Your First Task" : "Find Available Tasks"}</Btn>
          {role === "agent" && <p onClick={() => onComplete(role)} style={{ textAlign: "center", fontSize: 14, color: C.slate, marginTop: 12, cursor: "pointer" }}>Skip for now →</p>}
          {role === "runner" && <p style={{ textAlign: "center", fontSize: 13, color: C.slateLight, marginTop: 12 }}>You can complete your profile anytime</p>}
        </div>
      </div>
    );
  }
  // First Task Creation (Agent only) — delegates to FirstTaskStep component
  if (step === "firsttask") return <FirstTaskStep animKey={animKey} slideIn={slideIn} onBack={() => advance("welcome")} onFinish={(source) => onComplete(role, source)} />;

  return null;
};

const FirstTaskStep = ({ animKey, slideIn, onBack, onFinish }) => {
  const [cat, setCat] = useState(null);
  const [addr, setAddr] = useState("");
  const [price, setPrice] = useState("");
  const [notes, setNotes] = useState("");
  const [drafted, setDrafted] = useState(false);
  const saveDraft = () => { setDrafted(true); setTimeout(() => onFinish("drafted"), 1200); };
  const skipWithAutoSave = () => { if (cat || addr || price || notes) { setDrafted(true); setTimeout(() => onFinish("drafted"), 1200); } else onFinish(null); };
  if (drafted) return (
    <div key="drafted" style={{ minHeight: 756, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", background: C.white, padding: "0 40px", animation: "fadeUp 0.4s ease" }}>
      <div style={{ width: 64, height: 64, borderRadius: 32, background: C.greenLight, display: "flex", alignItems: "center", justifyContent: "center", marginBottom: 16 }}><Icon name="check" size={32} color={C.green} /></div>
      <h2 style={{ margin: "0 0 6px", fontSize: 22, fontWeight: 800, color: C.navy }}>Draft Saved!</h2>
      <p style={{ margin: 0, fontSize: 14, color: C.slate, textAlign: "center" }}>You'll find it on your Dashboard. Finish and post whenever you're ready.</p>
      <style>{`@keyframes fadeUp{from{opacity:0;transform:translateY(20px)}to{opacity:1;transform:translateY(0)}}`}</style>
    </div>
  );
  if (!cat) return (
    <div key={animKey} style={{ minHeight: 756, display: "flex", flexDirection: "column", background: C.white, padding: "0 24px", ...slideIn }}>
      <div style={{ padding: "20px 0 0", display: "flex", justifyContent: "space-between", alignItems: "center" }}>
        <div onClick={onBack} style={{ cursor: "pointer", padding: 4, display: "inline-flex" }}><Icon name="back" color={C.navy} size={22} /></div>
        <p onClick={skipWithAutoSave} style={{ margin: 0, fontSize: 14, color: C.red, fontWeight: 600, cursor: "pointer" }}>Skip</p>
      </div>
      <div style={{ padding: "16px 0 24px" }}>
        <h1 style={{ margin: "0 0 4px", fontSize: 26, fontWeight: 800, color: C.navy }}>Post your first task</h1>
        <p style={{ margin: 0, fontSize: 14, color: C.slate }}>What do you need help with?</p>
      </div>
      <div style={{ display: "flex", flexDirection: "column", gap: 10, flex: 1 }}>
        {[{ n: "Photography", d: "Professional listing photos", i: "camera", p: "$100–$300" }, { n: "Showing", d: "Represent you at a showing", i: "eye", p: "$50–$100" }, { n: "Staging", d: "Stage a property", i: "box", p: "$200–$500" }, { n: "Open House", d: "Host an open house", i: "home", p: "$75–$150" }].map(c => (
          <Card key={c.n} onClick={() => setCat(c.n)} style={{ padding: 16, display: "flex", alignItems: "center", gap: 14, cursor: "pointer" }}>
            <div style={{ width: 48, height: 48, borderRadius: 14, background: C.redLight, display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0 }}><Icon name={c.i} size={22} color={C.red} /></div>
            <div style={{ flex: 1 }}><span style={{ fontWeight: 700, fontSize: 15, color: C.navy }}>{c.n}</span><p style={{ margin: "2px 0 0", fontSize: 13, color: C.slate }}>{c.d}</p></div>
            <span style={{ fontSize: 12, color: C.slateLight }}>{c.p}</span>
          </Card>
        ))}
      </div>
      <div style={{ paddingBottom: 32 }}>
        <div style={{ display: "flex", alignItems: "center", justifyContent: "center", gap: 6 }}><Icon name="check" size={12} color={C.green} /><span style={{ fontSize: 12, color: C.slateLight }}>You can also do this later from your Dashboard</span></div>
      </div>
    </div>
  );
  return (
    <div key={`ft-${cat}`} style={{ minHeight: 756, display: "flex", flexDirection: "column", background: C.white, padding: "0 24px", ...slideIn }}>
      <div style={{ padding: "20px 0 0", display: "flex", justifyContent: "space-between", alignItems: "center" }}>
        <div onClick={() => setCat(null)} style={{ cursor: "pointer", padding: 4, display: "inline-flex" }}><Icon name="back" color={C.navy} size={22} /></div>
        <p onClick={skipWithAutoSave} style={{ margin: 0, fontSize: 14, color: C.red, fontWeight: 600, cursor: "pointer" }}>Skip</p>
      </div>
      <div style={{ padding: "16px 0 20px" }}>
        <div style={{ display: "flex", alignItems: "center", gap: 10, marginBottom: 8 }}>
          <div style={{ width: 36, height: 36, borderRadius: 10, background: C.redLight, display: "flex", alignItems: "center", justifyContent: "center" }}><Icon name={cat === "Photography" ? "camera" : cat === "Showing" ? "eye" : cat === "Staging" ? "box" : "home"} size={18} color={C.red} /></div>
          <h1 style={{ margin: 0, fontSize: 22, fontWeight: 800, color: C.navy }}>{cat}</h1>
        </div>
        <div style={{ display: "flex", gap: 4 }}>{[1,2].map(i => <div key={i} style={{ flex: 1, height: 4, borderRadius: 2, background: C.red }} />)}<div style={{ flex: 1, height: 4, borderRadius: 2, background: C.borderLight }} /></div>
      </div>
      <div style={{ display: "flex", flexDirection: "column", gap: 16, flex: 1 }}>
        <div>
          <label style={{ fontSize: 13, fontWeight: 600, color: C.navy, display: "block", marginBottom: 6 }}>Property Address</label>
          <input type="text" value={addr} onChange={e => setAddr(e.target.value)} placeholder="Enter property address" style={{ width: "100%", padding: "14px 16px", border: `1.5px solid ${C.border}`, borderRadius: 12, fontSize: 15, fontFamily: "'DM Sans',sans-serif", outline: "none", boxSizing: "border-box", background: C.white, color: C.navy }} />
        </div>
        <div>
          <label style={{ fontSize: 13, fontWeight: 600, color: C.navy, display: "block", marginBottom: 6 }}>Date & Time</label>
          <div style={{ display: "flex", alignItems: "center", gap: 10, padding: "14px 16px", border: `1.5px solid ${C.border}`, borderRadius: 12, background: C.white }}><Icon name="clock" size={16} color={C.slateLight} /><span style={{ fontSize: 14, color: C.slateLight }}>Select preferred date & time</span></div>
        </div>
        <div>
          <label style={{ fontSize: 13, fontWeight: 600, color: C.navy, display: "block", marginBottom: 6 }}>Your Price</label>
          <div style={{ display: "flex", alignItems: "center", gap: 6, padding: "14px 16px", border: `1.5px solid ${price ? C.red : C.border}`, borderRadius: 12, background: C.white, boxShadow: price ? `0 0 0 3px ${C.redGlow}` : "none" }}>
            <Icon name="dollar" size={16} color={C.red} />
            <input type="text" value={price} onChange={e => setPrice(e.target.value.replace(/[^0-9]/g, ""))} placeholder="150" style={{ border: "none", outline: "none", fontSize: 22, fontWeight: 800, fontFamily: "'DM Sans',sans-serif", background: "transparent", color: C.navy, width: "100%" }} />
          </div>
          <p style={{ margin: "6px 0 0", fontSize: 12, color: C.slateLight }}>Avg. for {cat.toLowerCase()} in Austin: $100–$200</p>
        </div>
        <div>
          <label style={{ fontSize: 13, fontWeight: 600, color: C.navy, display: "block", marginBottom: 6 }}>Special Instructions</label>
          <textarea value={notes} onChange={e => setNotes(e.target.value)} placeholder="Any details the task runner should know..." rows={3} style={{ width: "100%", padding: "14px 16px", border: `1.5px solid ${C.border}`, borderRadius: 12, fontSize: 14, fontFamily: "'DM Sans',sans-serif", outline: "none", boxSizing: "border-box", resize: "none", background: C.white, color: C.navy }} />
        </div>
      </div>
      <div style={{ paddingBottom: 32 }}>
        <div style={{ display: "flex", gap: 10 }}>
          <Btn variant="secondary" size="lg" style={{ flex: 1 }} onClick={saveDraft}>Save Draft</Btn>
          <Btn variant="primary" size="lg" style={{ flex: 1 }} onClick={() => onFinish("posted")}>Post Task</Btn>
        </div>
        <div style={{ display: "flex", alignItems: "center", justifyContent: "center", gap: 6, marginTop: 12 }}><Icon name="check" size={12} color={C.green} /><span style={{ fontSize: 12, color: C.slateLight }}>Auto-saving your progress</span></div>
      </div>
    </div>
  );
};

const ChatView = ({ task, role }) => { const [msg, setMsg] = useState(""); const isAgent = role === "agent"; return (<div style={{ padding: "0 20px 20px", display: "flex", flexDirection: "column" }}><div style={{ padding: "16px 0 12px", borderBottom: `1px solid ${C.borderLight}`, marginBottom: 12 }}><p style={{ margin: 0, fontSize: 13, color: C.slateLight }}>{task.type} · {task.address?.split(",")[0]}</p></div><div style={{ flex: 1, display: "flex", flexDirection: "column", gap: 8, marginBottom: 12, minHeight: 300 }}>{CHAT_MSGS.map(m => { const mine = (isAgent && m.from === "agent") || (!isAgent && m.from === "runner"); return (<div key={m.id} style={{ display: "flex", justifyContent: mine ? "flex-end" : "flex-start" }}><div style={{ maxWidth: "75%", padding: "10px 14px", borderRadius: mine ? "16px 16px 4px 16px" : "16px 16px 16px 4px", background: mine ? C.red : C.borderLight, color: mine ? "#fff" : C.navy }}><p style={{ margin: 0, fontSize: 14, lineHeight: 1.5 }}>{m.text}</p><p style={{ margin: "4px 0 0", fontSize: 11, opacity: 0.7, textAlign: "right" }}>{m.time}</p></div></div>); })}</div><div style={{ display: "flex", gap: 8, alignItems: "center" }}><div style={{ flex: 1, display: "flex", alignItems: "center", padding: "12px 16px", border: `1.5px solid ${C.border}`, borderRadius: 24, background: C.white }}><input type="text" value={msg} onChange={e => setMsg(e.target.value)} placeholder="Type a message..." style={{ border: "none", outline: "none", flex: 1, fontSize: 14, fontFamily: "'DM Sans',sans-serif", background: "transparent" }} /></div><div style={{ width: 44, height: 44, borderRadius: 22, background: C.red, display: "flex", alignItems: "center", justifyContent: "center", cursor: "pointer", flexShrink: 0 }}><Icon name="send" size={18} color="#fff" /></div></div></div>); };

const AgentDash = ({ onTaskTap, onCreateTask, onboardDismissed, onDismissOnboard, onFilterTap, onboardSource, onDismissSource, onProfileStep, onViewNewTask }) => { const posted = TASKS.filter(t => t.status === "posted").length; const inProg = TASKS.filter(t => t.status === "in_progress").length; const completed = TASKS.filter(t => t.status === "completed").length; return (<div style={{ padding: "0 20px 20px" }}><div style={{ padding: "20px 0 16px" }}><p style={{ margin: 0, fontSize: 14, color: C.slate }}>Good afternoon</p><h1 style={{ margin: "2px 0 0", fontSize: 26, fontWeight: 800, color: C.navy, letterSpacing: -0.5 }}>Daniel</h1></div>{onboardSource && <Card style={{ marginBottom: 16, padding: 16, border: `1.5px solid ${onboardSource === "posted" ? C.green : C.amber}`, background: onboardSource === "posted" ? C.greenLight : C.amberLight, position: "relative", animation: "fadeUp 0.4s ease", cursor: "pointer" }} onClick={onViewNewTask}><div style={{ display: "flex", alignItems: "center", gap: 12 }}><div style={{ width: 44, height: 44, borderRadius: 12, background: onboardSource === "posted" ? "#D1FAE5" : "#FEF3C7", display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0 }}><Icon name={onboardSource === "posted" ? "check" : "edit"} size={22} color={onboardSource === "posted" ? C.green : C.amber} /></div><div style={{ flex: 1 }}><p style={{ margin: 0, fontSize: 15, fontWeight: 700, color: C.navy }}>{onboardSource === "posted" ? "🎉 Your first task is live!" : "📝 Draft saved!"}</p><p style={{ margin: "4px 0 0", fontSize: 13, color: C.slate }}>{onboardSource === "posted" ? "Nearby runners are being notified." : "Your task draft is ready to finish."}</p><p style={{ margin: "8px 0 0", fontSize: 13, fontWeight: 600, color: onboardSource === "posted" ? C.green : C.amber }}>{onboardSource === "posted" ? "View Task →" : "Finish Draft →"}</p></div></div><div onClick={(e) => { e.stopPropagation(); onDismissSource(); }} style={{ position: "absolute", top: 10, right: 10, cursor: "pointer", width: 24, height: 24, borderRadius: 12, background: "rgba(0,0,0,0.06)", display: "flex", alignItems: "center", justifyContent: "center" }}><Icon name="x" size={12} color={C.slate} /></div><style>{`@keyframes fadeUp{from{opacity:0;transform:translateY(12px)}to{opacity:1;transform:translateY(0)}}`}</style></Card>}{!onboardDismissed && <Card style={{ background: `linear-gradient(135deg, ${C.navy} 0%, ${C.navyMid} 100%)`, border: "none", marginBottom: 16, padding: 20, position: "relative" }}><div onClick={onDismissOnboard} style={{ position: "absolute", top: 12, right: 12, cursor: "pointer", width: 28, height: 28, borderRadius: 14, background: "rgba(255,255,255,0.12)", display: "flex", alignItems: "center", justifyContent: "center" }}><Icon name="x" size={14} color="rgba(255,255,255,0.7)" /></div><div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 12, paddingRight: 28 }}><span style={{ color: "#fff", fontSize: 14, fontWeight: 600 }}>Complete your profile</span><span style={{ color: C.slateLight, fontSize: 13 }}>3 of 5</span></div><ProgressBar value={60} dark /><div style={{ display: "flex", gap: 8, marginTop: 14, flexWrap: "wrap" }}>{[{ label: "Add photo", screen: "personal" }, { label: "Payment method", screen: "payment" }].map(s => <span key={s.label} onClick={(e) => { e.stopPropagation(); onProfileStep(s.screen); }} style={{ background: "rgba(255,255,255,0.12)", color: "rgba(255,255,255,0.8)", fontSize: 12, padding: "5px 12px", borderRadius: 20, fontWeight: 500, cursor: "pointer" }}>{s.label}</span>)}</div></Card>}<div style={{ display: "grid", gridTemplateColumns: "1fr 1fr 1fr", gap: 10, marginBottom: 20 }}>{[{ label: "Posted", count: posted, color: C.blue, bg: C.blueLight, filter: "posted" }, { label: "In Progress", count: inProg, color: C.amber, bg: C.amberLight, filter: "in_progress" }, { label: "Completed", count: completed, color: C.green, bg: C.greenLight, filter: "completed" }].map(w => (<Card key={w.label} onClick={() => onFilterTap(w.filter)} style={{ padding: 14, textAlign: "center" }}><div style={{ width: 36, height: 36, borderRadius: 10, background: w.bg, display: "flex", alignItems: "center", justifyContent: "center", margin: "0 auto 8px", fontSize: 18, fontWeight: 800, color: w.color }}>{w.count}</div><span style={{ fontSize: 12, color: C.slate, fontWeight: 500 }}>{w.label}</span></Card>))}</div><Btn variant="primary" size="lg" full onClick={onCreateTask}><Icon name="plus" size={18} color="#fff" /> Create Task</Btn><div style={{ marginTop: 24 }}><SectionHead title="Recent Tasks" action="View All" onAction={() => onFilterTap("all")} /><div style={{ display: "flex", flexDirection: "column", gap: 10 }}>{TASKS.slice(0, 4).map(t => <TaskCard key={t.id} task={t} onClick={() => onTaskTap(t)} showRunner />)}</div></div></div>); };

const RunnerDash = ({ onTaskTap, onOpenFilter, userLocation, onChangeLoc }) => { const [searchQ, setSearchQ] = useState(""); const [activeCat, setActiveCat] = useState("All"); const filtered = AVAILABLE.filter(t => { const catMatch = activeCat === "All" || t.type === activeCat || (activeCat === "Showings" && t.type === "Showing"); const q = searchQ.toLowerCase(); const searchMatch = !q || t.type.toLowerCase().includes(q) || t.address.toLowerCase().includes(q) || (t.desc || "").toLowerCase().includes(q); return catMatch && searchMatch; }); return (<div style={{ padding: "0 20px 20px" }}><div style={{ padding: "20px 0 16px" }}><p style={{ margin: 0, fontSize: 14, color: C.slate }}>Good afternoon</p><h1 style={{ margin: "2px 0 0", fontSize: 26, fontWeight: 800, color: C.navy, letterSpacing: -0.5 }}>Maria</h1></div><Card style={{ background: `linear-gradient(135deg, ${C.navy} 0%, ${C.navyMid} 100%)`, border: "none", marginBottom: 16, padding: 20 }}><div style={{ display: "flex", justifyContent: "space-between" }}><div><p style={{ margin: 0, fontSize: 13, color: C.slateLight }}>This Week</p><p style={{ margin: "4px 0 0", fontSize: 32, fontWeight: 800, color: "#fff", letterSpacing: -1 }}>$475</p></div><div style={{ textAlign: "right" }}><p style={{ margin: 0, fontSize: 13, color: C.slateLight }}>Completed</p><p style={{ margin: "4px 0 0", fontSize: 32, fontWeight: 800, color: "#fff", letterSpacing: -1 }}>3</p></div></div></Card><div onClick={onChangeLoc} style={{ display: "flex", alignItems: "center", gap: 8, padding: "10px 14px", background: C.redGlow, borderRadius: 12, marginBottom: 14, border: `1px solid ${C.redLight}`, cursor: "pointer" }}><Icon name="mappin" size={16} color={C.red} /><span style={{ fontSize: 13, fontWeight: 600, color: C.navy, flex: 1 }}>{userLocation}</span><span style={{ fontSize: 12, color: C.red, fontWeight: 600 }}>Change</span></div><h3 style={{ margin: "0 0 10px", fontSize: 17, fontWeight: 700, color: C.navy }}>Find Tasks</h3><div style={{ display: "flex", alignItems: "center", gap: 10, background: C.white, border: `1.5px solid ${C.border}`, borderRadius: 12, padding: "12px 16px", marginBottom: 14 }}><Icon name="search" size={18} color={C.slateLight} /><input type="text" value={searchQ} onChange={e => setSearchQ(e.target.value)} placeholder="Search type, address, description..." style={{ border: "none", outline: "none", flex: 1, fontSize: 14, fontFamily: "'DM Sans',sans-serif", background: "transparent", color: C.navy }} />{searchQ && <div onClick={() => setSearchQ("")} style={{ cursor: "pointer" }}><Icon name="x" size={16} color={C.slateLight} /></div>}</div><div style={{ display: "flex", gap: 8, marginBottom: 20, overflowX: "auto" }}>{["All", "Photography", "Showings", "Staging"].map(f => <span key={f} onClick={() => setActiveCat(f)} style={{ padding: "8px 16px", borderRadius: 9999, fontSize: 13, fontWeight: 600, background: activeCat === f ? C.red : C.white, color: activeCat === f ? "#fff" : C.slate, border: activeCat === f ? "none" : `1.5px solid ${C.border}`, cursor: "pointer", whiteSpace: "nowrap" }}>{f}</span>)}</div><SectionHead title="Available Tasks" right={<div onClick={onOpenFilter} style={{ width: 36, height: 36, borderRadius: 12, border: `1.5px solid ${C.border}`, display: "flex", alignItems: "center", justifyContent: "center", cursor: "pointer", background: C.white }}><Icon name="filter" size={16} color={C.slate} /></div>} /><p style={{ margin: "-8px 0 12px", fontSize: 13, color: C.slateLight }}>{filtered.length} tasks nearby</p><div style={{ display: "flex", flexDirection: "column", gap: 10 }}>{filtered.map(t => (<Card key={t.id} onClick={() => onTaskTap(t)} style={{ padding: 16 }}><div style={{ display: "flex", gap: 14, alignItems: "flex-start" }}><div style={{ width: 42, height: 42, borderRadius: 12, background: C.redLight, display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0 }}><Icon name={catIcon(t.type)} size={20} color={C.red} /></div><div style={{ flex: 1 }}><div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 4 }}><span style={{ fontWeight: 700, fontSize: 15, color: C.navy }}>{t.type}</span><span style={{ fontSize: 17, fontWeight: 800, color: C.red }}>${t.price}</span></div><p style={{ margin: "0 0 6px", fontSize: 13, color: C.slate }}>{t.address}</p><div style={{ display: "flex", justifyContent: "space-between" }}><span style={{ fontSize: 12, color: C.slateLight }}>Posted {t.posted}</span><span style={{ fontSize: 12, color: C.slateLight, display: "flex", alignItems: "center", gap: 4 }}><Icon name="map" size={12} color={C.slateLight} /> {t.distance}</span></div></div></div></Card>))}{filtered.length === 0 && <div style={{ textAlign: "center", padding: "40px 20px" }}><div style={{ width: 64, height: 64, borderRadius: 20, background: C.borderLight, display: "flex", alignItems: "center", justifyContent: "center", margin: "0 auto 16px" }}><Icon name="search" size={28} color={C.slateLight} /></div><p style={{ fontSize: 16, fontWeight: 700, color: C.navy, margin: "0 0 6px" }}>No tasks match</p><p style={{ fontSize: 13, color: C.slate }}>Try adjusting your search or filters</p></div>}</div></div>); };

const FilterSheet = ({ onClose, userLocation }) => { const [cats, setCats] = useState({ Photography: true, Showing: true, Staging: true, "Open House": false }); const [radius, setRadius] = useState("10 mi"); const [locMode, setLocMode] = useState("auto"); const toggleCat = c => setCats(p => ({ ...p, [c]: !p[c] })); return (<div style={{ padding: "8px 20px 32px" }}><div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", padding: "12px 0 16px" }}><h2 style={{ margin: 0, fontSize: 22, fontWeight: 800, color: C.navy }}>Filter Tasks</h2><div onClick={onClose} style={{ cursor: "pointer", width: 30, height: 30, borderRadius: 15, background: C.borderLight, display: "flex", alignItems: "center", justifyContent: "center" }}><Icon name="x" size={16} color={C.slate} /></div></div><p style={{ margin: "0 0 10px", fontSize: 14, fontWeight: 700, color: C.navy }}>Location</p><div style={{ display: "flex", gap: 8, marginBottom: 12 }}>{["auto", "manual"].map(m => (<div key={m} onClick={() => setLocMode(m)} style={{ flex: 1, padding: "12px 16px", borderRadius: 12, border: `1.5px solid ${locMode === m ? C.red : C.border}`, background: locMode === m ? C.redGlow : C.white, cursor: "pointer", textAlign: "center" }}><Icon name={m === "auto" ? "crosshair" : "mappin"} size={18} color={locMode === m ? C.red : C.slate} /><p style={{ margin: "6px 0 0", fontSize: 13, fontWeight: 600, color: locMode === m ? C.red : C.navy }}>{m === "auto" ? "Use My Location" : "Set Manually"}</p></div>))}</div>{locMode === "auto" && <div style={{ display: "flex", alignItems: "center", gap: 8, padding: "10px 14px", background: C.greenLight, borderRadius: 10, marginBottom: 16 }}><Icon name="check" size={14} color={C.green} /><span style={{ fontSize: 13, color: C.green, fontWeight: 500 }}>Using current location: {userLocation || "Austin, TX"}</span></div>}{locMode === "manual" && <div style={{ display: "flex", alignItems: "center", gap: 10, padding: "12px 16px", border: `1.5px solid ${C.border}`, borderRadius: 12, background: C.white, marginBottom: 16 }}><Icon name="search" size={16} color={C.slateLight} /><span style={{ fontSize: 14, color: C.slateLight }}>Search city or ZIP code...</span></div>}<p style={{ margin: "0 0 10px", fontSize: 14, fontWeight: 700, color: C.navy }}>Search Radius</p><div style={{ display: "flex", gap: 8, marginBottom: 20, flexWrap: "wrap" }}>{["3 mi", "5 mi", "10 mi", "15 mi", "25 mi"].map(r => <span key={r} onClick={() => setRadius(r)} style={{ padding: "8px 16px", borderRadius: 9999, fontSize: 13, fontWeight: 600, background: radius === r ? C.red : C.white, color: radius === r ? "#fff" : C.slate, border: radius === r ? "none" : `1.5px solid ${C.border}`, cursor: "pointer" }}>{r}</span>)}</div><p style={{ margin: "0 0 10px", fontSize: 14, fontWeight: 700, color: C.navy }}>Task Categories</p><div style={{ display: "flex", flexDirection: "column", gap: 8, marginBottom: 24 }}>{Object.entries(cats).map(([cat, on]) => (<div key={cat} onClick={() => toggleCat(cat)} style={{ display: "flex", alignItems: "center", justifyContent: "space-between", padding: "12px 16px", borderRadius: 12, border: `1.5px solid ${on ? C.red : C.border}`, background: on ? C.redGlow : C.white, cursor: "pointer" }}><div style={{ display: "flex", alignItems: "center", gap: 10 }}><Icon name={catIcon(cat)} size={18} color={on ? C.red : C.slate} /><span style={{ fontSize: 14, fontWeight: 600, color: on ? C.red : C.navy }}>{cat}</span></div>{on && <Icon name="check" size={16} color={C.red} />}</div>))}</div><div style={{ display: "flex", gap: 10 }}><Btn variant="secondary" size="lg" style={{ flex: 1 }}>Reset</Btn><Btn variant="primary" size="lg" style={{ flex: 1 }} onClick={onClose}>Apply Filters</Btn></div></div>); };
const FilteredTaskList = ({ filter, onTaskTap }) => { const labels = { all: "All Tasks", posted: "Posted Tasks", in_progress: "In Progress", completed: "Completed Tasks" }; const tasks = filter === "all" ? TASKS : TASKS.filter(t => t.status === filter); return (<div style={{ padding: "0 20px 20px" }}><h2 style={{ margin: "20px 0 4px", fontSize: 22, fontWeight: 800, color: C.navy }}>{labels[filter]}</h2><p style={{ margin: "0 0 16px", fontSize: 14, color: C.slateLight }}>{tasks.length} task{tasks.length !== 1 ? "s" : ""}</p><div style={{ display: "flex", flexDirection: "column", gap: 10 }}>{tasks.map(t => <TaskCard key={t.id} task={t} onClick={() => onTaskTap(t)} showRunner />)}</div>{tasks.length === 0 && <div style={{ textAlign: "center", padding: "40px 20px" }}><div style={{ width: 64, height: 64, borderRadius: 20, background: C.borderLight, display: "flex", alignItems: "center", justifyContent: "center", margin: "0 auto 16px" }}><Icon name="search" size={28} color={C.slateLight} /></div><p style={{ fontSize: 16, fontWeight: 700, color: C.navy, margin: "0 0 6px" }}>No tasks found</p></div>}</div>); };

const TaskDetail = ({ task, role, onChat, onAccept, taskStatus }) => { const isRunner = role === "runner"; const sts = taskStatus || task.status; const b = sts ? statusBadge(sts) : null; return (<div style={{ padding: "0 20px 20px" }}><div style={{ padding: "20px 0 8px", display: "flex", justifyContent: "space-between", alignItems: "center" }}><div style={{ display: "flex", alignItems: "center", gap: 10 }}><div style={{ width: 48, height: 48, borderRadius: 14, background: C.redLight, display: "flex", alignItems: "center", justifyContent: "center" }}><Icon name={catIcon(task.type)} size={24} color={C.red} /></div><div><h2 style={{ margin: 0, fontSize: 22, fontWeight: 800, color: C.navy }}>{task.type}</h2><span style={{ fontSize: 13, color: C.slate }}>{isRunner ? `Posted by ${task.agent || "Agent"}` : task.runner ? `Assigned to ${task.runner}` : "Awaiting acceptance"}</span></div></div>{b && <Badge {...b} />}</div><Card style={{ marginTop: 16, padding: 20, textAlign: "center", background: C.redGlow, border: `1.5px solid ${C.redLight}` }}><p style={{ margin: 0, fontSize: 13, color: C.slate, fontWeight: 500 }}>Task Payout</p><p style={{ margin: "4px 0 0", fontSize: 36, fontWeight: 800, color: C.red, letterSpacing: -1 }}>${task.price}</p></Card><div style={{ marginTop: 20 }}><h3 style={{ margin: "0 0 14px", fontSize: 16, fontWeight: 700, color: C.navy }}>Task Details</h3>{[{ icon: "map", label: "Location", value: task.address }, { icon: "clock", label: "Scheduled", value: task.time || "Flexible" }, ...(task.distance ? [{ icon: "mappin", label: "Distance", value: task.distance }] : [])].map((d, i) => (<div key={i} style={{ display: "flex", alignItems: "center", gap: 14, padding: "12px 0", borderBottom: `1px solid ${C.borderLight}` }}><div style={{ width: 36, height: 36, borderRadius: 10, background: C.borderLight, display: "flex", alignItems: "center", justifyContent: "center" }}><Icon name={d.icon} size={16} color={C.slate} /></div><div><p style={{ margin: 0, fontSize: 12, color: C.slateLight }}>{d.label}</p><p style={{ margin: "2px 0 0", fontSize: 14, fontWeight: 600, color: C.navy }}>{d.value}</p></div></div>))}</div><Card style={{ marginTop: 20, background: C.borderLight, border: "none" }}><p style={{ margin: "0 0 6px", fontSize: 13, fontWeight: 700, color: C.navy }}>Special Instructions</p><p style={{ margin: 0, fontSize: 13, color: C.slate, lineHeight: 1.5 }}>{task.desc || "No special instructions."}</p></Card>{sts === "pending" && <Card style={{ marginTop: 16, background: C.amberLight, border: `1px solid ${C.amber}`, textAlign: "center" }}><div style={{ display: "flex", alignItems: "center", justifyContent: "center", gap: 8 }}><div style={{ width: 20, height: 20, border: `2.5px solid ${C.amber}`, borderTopColor: "transparent", borderRadius: "50%", animation: "spin 0.8s linear infinite" }} /><span style={{ fontSize: 14, fontWeight: 600, color: C.amber }}>Application submitted — awaiting confirmation</span></div><style>{`@keyframes spin{to{transform:rotate(360deg)}}`}</style></Card>}<div style={{ marginTop: 24, display: "flex", flexDirection: "column", gap: 10 }}>{isRunner && !sts ? (<><Btn variant="secondary" size="lg" full onClick={onChat}><Icon name="message" size={16} color={C.navy} /> Ask a Question</Btn><Btn variant="primary" size="lg" full onClick={onAccept}><Icon name="check" size={16} color="#fff" /> Accept Task</Btn></>) : isRunner && sts === "pending" ? (<Btn variant="secondary" size="lg" full onClick={onChat}><Icon name="message" size={16} color={C.navy} /> Message Agent</Btn>) : isRunner && sts === "in_progress" ? (<div style={{ display: "flex", gap: 10 }}><Btn variant="secondary" size="lg" style={{ flex: 1 }} onClick={onChat}><Icon name="message" size={16} color={C.navy} /> Message</Btn><Btn variant="primary" size="lg" style={{ flex: 1 }}>Submit Deliverables</Btn></div>) : !isRunner && sts === "completed" ? (<div style={{ display: "flex", gap: 10 }}><Btn variant="secondary" size="lg" style={{ flex: 1 }}>Request Revision</Btn><Btn variant="primary" size="lg" style={{ flex: 1 }}>Approve & Pay</Btn></div>) : !isRunner && (sts === "in_progress" || sts === "posted") ? (<Btn variant="secondary" size="lg" full onClick={onChat}><Icon name="message" size={16} color={C.navy} /> Message {task.runner || "Runner"}</Btn>) : !isRunner && sts === "draft" ? (<Btn variant="primary" size="lg" full><Icon name="edit" size={16} color="#fff" /> Edit & Post Task</Btn>) : null}</div></div>); };

const TaskCreationSheet = ({ onClose, onPost }) => { const [step, setStep] = useState(0); const [cat, setCat] = useState(null); if (step === 0) return (<div style={{ padding: "8px 20px 32px" }}><div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", padding: "12px 0 16px" }}><h2 style={{ margin: 0, fontSize: 22, fontWeight: 800, color: C.navy }}>New Task</h2><div onClick={onClose} style={{ cursor: "pointer", width: 30, height: 30, borderRadius: 15, background: C.borderLight, display: "flex", alignItems: "center", justifyContent: "center" }}><Icon name="x" size={16} color={C.slate} /></div></div><p style={{ margin: "0 0 20px", fontSize: 14, color: C.slate }}>What do you need help with?</p><div style={{ display: "flex", flexDirection: "column", gap: 10 }}>{[{ n: "Photography", d: "Professional listing photos", i: "camera", p: "$100-$300" }, { n: "Showing", d: "Represent you at a showing", i: "eye", p: "$50-$100" }, { n: "Staging", d: "Stage a property", i: "box", p: "$200-$500" }, { n: "Open House", d: "Host an open house", i: "home", p: "$75-$150" }].map(c => (<Card key={c.n} onClick={() => { setCat(c.n); setStep(1); }} style={{ padding: 16, display: "flex", alignItems: "center", gap: 16, cursor: "pointer" }}><div style={{ width: 48, height: 48, borderRadius: 14, background: C.redLight, display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0 }}><Icon name={c.i} size={22} color={C.red} /></div><div style={{ flex: 1 }}><span style={{ fontWeight: 700, fontSize: 15, color: C.navy }}>{c.n}</span><p style={{ margin: "2px 0 0", fontSize: 13, color: C.slate }}>{c.d}</p></div><div style={{ textAlign: "right" }}><span style={{ fontSize: 12, color: C.slateLight }}>{c.p}</span><div><Icon name="chevron" size={16} color={C.slateLight} /></div></div></Card>))}</div></div>); return (<div style={{ padding: "8px 20px 32px" }}><div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", padding: "12px 0 16px" }}><h2 style={{ margin: 0, fontSize: 20, fontWeight: 800, color: C.navy }}>{cat}</h2><div onClick={onClose} style={{ cursor: "pointer", width: 30, height: 30, borderRadius: 15, background: C.borderLight, display: "flex", alignItems: "center", justifyContent: "center" }}><Icon name="x" size={16} color={C.slate} /></div></div><div style={{ display: "flex", gap: 6, marginBottom: 24 }}>{[1,2,3].map(s => <div key={s} style={{ flex: 1, height: 4, borderRadius: 2, background: s === 1 ? C.red : C.borderLight }} />)}</div><div style={{ display: "flex", flexDirection: "column", gap: 16 }}>{[{ l: "Property Address", i: "map", ph: "Enter property address" }, { l: "Date & Time", i: "clock", ph: "Select preferred date & time" }].map(f => (<div key={f.l}><label style={{ fontSize: 13, fontWeight: 600, color: C.navy, display: "block", marginBottom: 6 }}>{f.l}</label><div style={{ display: "flex", alignItems: "center", gap: 10, padding: "14px 16px", border: `1.5px solid ${C.border}`, borderRadius: 12, background: C.white }}><Icon name={f.i} size={16} color={C.slateLight} /><span style={{ fontSize: 14, color: C.slateLight }}>{f.ph}</span></div></div>))}<div><label style={{ fontSize: 13, fontWeight: 600, color: C.navy, display: "block", marginBottom: 6 }}>Your Price</label><div style={{ display: "flex", alignItems: "center", gap: 10, padding: "14px 16px", border: `1.5px solid ${C.red}`, borderRadius: 12, background: C.white, boxShadow: `0 0 0 3px ${C.redGlow}` }}><Icon name="dollar" size={16} color={C.red} /><span style={{ fontSize: 22, fontWeight: 800, color: C.navy }}>150</span></div><p style={{ margin: "6px 0 0", fontSize: 12, color: C.slateLight }}>Avg. for {cat?.toLowerCase()} in Austin: $100-$200</p></div><div><label style={{ fontSize: 13, fontWeight: 600, color: C.navy, display: "block", marginBottom: 6 }}>Special Instructions</label><div style={{ padding: "14px 16px", minHeight: 80, border: `1.5px solid ${C.border}`, borderRadius: 12, background: C.white }}><span style={{ fontSize: 14, color: C.slateLight }}>Any details the task runner should know...</span></div></div></div><div style={{ marginTop: 24, display: "flex", gap: 10 }}><Btn variant="secondary" size="lg" style={{ flex: 1 }} onClick={onClose}>Save Draft</Btn><Btn variant="primary" size="lg" style={{ flex: 1 }} onClick={() => onPost({ id: 99, type: cat, address: "1234 New Listing Dr, Austin TX", price: 150, status: "posted", time: "Tomorrow, 10:00 AM", runner: null, desc: "New task." })}>Post Task</Btn></div><div style={{ display: "flex", alignItems: "center", justifyContent: "center", gap: 6, marginTop: 12 }}><Icon name="check" size={12} color={C.green} /><span style={{ fontSize: 12, color: C.slateLight }}>Auto-saving your progress</span></div></div>); };

const LocationPicker = ({ current, onSelect, onClose }) => { const [searchQ, setSearchQ] = useState(""); const [mode, setMode] = useState("search");
  const cities = [{ name: "Austin, TX", sub: "Current location" }, { name: "New York, NY", sub: "Manhattan, Brooklyn, Queens" }, { name: "Brooklyn, NY", sub: "Williamsburg, DUMBO, Park Slope" }, { name: "Virginia Beach, VA", sub: "Oceanfront, Town Center" }, { name: "Dallas, TX", sub: "Uptown, Deep Ellum, Bishop Arts" }, { name: "San Antonio, TX", sub: "Pearl District, Riverwalk" }];
  const filtered = searchQ ? cities.filter(c => c.name.toLowerCase().includes(searchQ.toLowerCase())) : cities;
  return (<div style={{ padding: "8px 20px 32px" }}>
    <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", padding: "12px 0 16px" }}><h2 style={{ margin: 0, fontSize: 22, fontWeight: 800, color: C.navy }}>Change Location</h2><div onClick={onClose} style={{ cursor: "pointer", width: 30, height: 30, borderRadius: 15, background: C.borderLight, display: "flex", alignItems: "center", justifyContent: "center" }}><Icon name="x" size={16} color={C.slate} /></div></div>
    <div style={{ display: "flex", gap: 8, marginBottom: 16 }}>{["search", "auto"].map(m => (
      <div key={m} onClick={() => setMode(m)} style={{ flex: 1, padding: "12px 16px", borderRadius: 12, border: `1.5px solid ${mode === m ? C.red : C.border}`, background: mode === m ? C.redGlow : C.white, cursor: "pointer", textAlign: "center" }}>
        <Icon name={m === "auto" ? "crosshair" : "search"} size={18} color={mode === m ? C.red : C.slate} />
        <p style={{ margin: "6px 0 0", fontSize: 13, fontWeight: 600, color: mode === m ? C.red : C.navy }}>{m === "auto" ? "Use My Location" : "Search"}</p>
      </div>))}</div>
    {mode === "auto" ? (<div>
      <div style={{ display: "flex", alignItems: "center", gap: 8, padding: "14px 16px", background: C.greenLight, borderRadius: 12, marginBottom: 16 }}><Icon name="crosshair" size={16} color={C.green} /><span style={{ fontSize: 14, fontWeight: 500, color: C.green, flex: 1 }}>Detected: Austin, TX</span></div>
      <Btn variant="primary" size="lg" full onClick={() => { onSelect("Austin, TX"); onClose(); }}>Use Current Location</Btn>
    </div>) : (<div>
      <div style={{ display: "flex", alignItems: "center", gap: 10, padding: "12px 16px", border: `1.5px solid ${C.border}`, borderRadius: 12, background: C.white, marginBottom: 16 }}>
        <Icon name="search" size={16} color={C.slateLight} />
        <input type="text" value={searchQ} onChange={e => setSearchQ(e.target.value)} placeholder="Search city or ZIP code..." style={{ border: "none", outline: "none", flex: 1, fontSize: 14, fontFamily: "'DM Sans',sans-serif", background: "transparent", color: C.navy }} />
        {searchQ && <div onClick={() => setSearchQ("")} style={{ cursor: "pointer" }}><Icon name="x" size={14} color={C.slateLight} /></div>}
      </div>
      <div style={{ display: "flex", flexDirection: "column", gap: 6 }}>
        {filtered.map(c => (<div key={c.name} onClick={() => { onSelect(c.name); onClose(); }} style={{ display: "flex", alignItems: "center", gap: 12, padding: "14px 16px", borderRadius: 12, border: `1.5px solid ${current === c.name ? C.red : C.border}`, background: current === c.name ? C.redGlow : C.white, cursor: "pointer" }}>
          <Icon name="mappin" size={18} color={current === c.name ? C.red : C.slate} />
          <div style={{ flex: 1 }}><span style={{ fontSize: 14, fontWeight: 600, color: C.navy }}>{c.name}</span>{c.sub && <p style={{ margin: "2px 0 0", fontSize: 12, color: C.slateLight }}>{c.sub}</p>}</div>
          {current === c.name && <Icon name="check" size={16} color={C.red} />}
        </div>))}
        {filtered.length === 0 && <p style={{ textAlign: "center", padding: 20, fontSize: 14, color: C.slateLight }}>No results for "{searchQ}"</p>}
      </div>
    </div>)}
  </div>);
};

const NotificationsScreen = ({ onNotifTap, onSettings }) => (<div style={{ padding: "0 20px 20px" }}><div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", margin: "20px 0 16px" }}><h2 style={{ margin: 0, fontSize: 22, fontWeight: 800, color: C.navy }}>Notifications</h2><div onClick={onSettings} style={{ width: 36, height: 36, borderRadius: 12, border: `1.5px solid ${C.border}`, display: "flex", alignItems: "center", justifyContent: "center", cursor: "pointer", background: C.white }}><Icon name="settings" size={18} color={C.slate} /></div></div>{NOTIFS.map(n => (<Card key={n.id} onClick={() => onNotifTap(n)} style={{ padding: 16, display: "flex", gap: 14, alignItems: "flex-start", marginBottom: 8, background: n.read ? C.white : C.redGlow, borderColor: n.read ? C.border : C.redLight, cursor: "pointer" }}><div style={{ width: 40, height: 40, borderRadius: 12, background: n.read ? C.borderLight : C.redLight, display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0 }}><Icon name={n.iconName} size={18} color={n.read ? C.slate : C.red} /></div><div style={{ flex: 1 }}><div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}><span style={{ fontWeight: 700, fontSize: 14, color: C.navy }}>{n.title}</span>{!n.read && <div style={{ width: 8, height: 8, borderRadius: 4, background: C.red }} />}</div><p style={{ margin: "4px 0 0", fontSize: 13, color: C.slate, lineHeight: 1.4 }}>{n.message}</p><span style={{ fontSize: 12, color: C.slateLight, marginTop: 4, display: "block" }}>{n.time}</span></div><Icon name="chevron" size={16} color={C.slateLight} /></Card>))}</div>);

const ProfileHome = ({ role, onRoleSwitch, onNavigate }) => (<div><div style={{ background: `linear-gradient(135deg, ${C.navy} 0%, ${C.navyMid} 100%)`, padding: "32px 20px 40px", textAlign: "center", position: "relative" }}><div style={{ display: "flex", justifyContent: "center", marginBottom: 12 }}><div style={{ border: `3px solid rgba(255,255,255,0.3)`, borderRadius: 42, padding: 2 }}><Avatar name={role === "agent" ? "Daniel M" : "Maria S"} size={80} /></div></div><h2 style={{ margin: "0 0 2px", fontSize: 22, fontWeight: 800, color: "#fff" }}>{role === "agent" ? "Daniel Martinez" : "Maria Santos"}</h2><p style={{ margin: 0, fontSize: 14, color: C.slateLight }}>{role === "agent" ? "Real Estate Agent" : "Task Runner"} · Austin, TX</p>{role === "runner" && <div style={{ display: "flex", justifyContent: "center", gap: 4, marginTop: 8 }}>{[1,2,3,4,5].map(i => <Icon key={i} name="star" size={14} color={i <= 4 ? "#FBBF24" : "rgba(255,255,255,0.2)"} />)}<span style={{ fontSize: 13, color: "rgba(255,255,255,0.7)", marginLeft: 4 }}>4.0</span></div>}<div style={{ marginTop: 12 }}><Btn variant="small" style={{ background: "rgba(255,255,255,0.15)", color: "#fff" }} onClick={() => onNavigate("personal")}>Edit Profile</Btn></div></div><div style={{ padding: "16px 20px 20px" }}><Card style={{ marginBottom: 12 }}><MenuRow icon="user" label="Personal Information" onClick={() => onNavigate("personal")} /><MenuRow icon="creditcard" label={role === "agent" ? "Payment Methods" : "Payout Settings"} onClick={() => onNavigate("payment")} /><MenuRow icon="bell" label="Notification Settings" onClick={() => onNavigate("notifSettings")} /><MenuRow icon={role === "agent" ? "clock" : "trending"} label={role === "agent" ? "Task History" : "Earnings & Payouts"} onClick={() => onNavigate("history")} />{role === "runner" && <MenuRow icon="mappin" label="Service Areas" onClick={() => onNavigate("serviceAreas")} />}{role === "runner" && <MenuRow icon="calendar" label="Availability" onClick={() => onNavigate("availability")} />}<MenuRow icon="shield" label="Account & Security" onClick={() => onNavigate("security")} last /></Card><Card style={{ padding: 16, textAlign: "center", cursor: "pointer", background: C.borderLight, border: `1.5px dashed ${C.slateLight}` }} onClick={onRoleSwitch}><div style={{ display: "flex", alignItems: "center", justifyContent: "center", gap: 8 }}><Icon name="refresh" size={16} color={C.slate} /><span style={{ fontSize: 13, fontWeight: 600, color: C.slate }}>Demo: Switch to {role === "agent" ? "Task Runner" : "Agent"} View</span></div></Card></div></div>);
const PersonalInfoScreen = ({ role }) => { const a = role === "agent"; return (<div style={{ padding: "0 20px 20px" }}><div style={{ textAlign: "center", padding: "20px 0 16px" }}><Avatar name={a ? "Daniel M" : "Maria S"} size={72} /><div style={{ marginTop: 10 }}><Btn variant="small"><Icon name="camera" size={14} color={C.red} /> Change Photo</Btn></div></div><Card><FieldRow label="Full Name" value={a ? "Daniel Martinez" : "Maria Santos"} icon="user" /><FieldRow label="Email" value={a ? "daniel@realty.com" : "maria@realty.com"} icon="mail" /><FieldRow label="Phone" value={a ? "(512) 555-0147" : "(512) 555-0293"} icon="phone" /><FieldRow label="Brokerage" value={a ? "Compass Austin" : "RE/MAX Capital City"} icon="building" /><FieldRow label="License #" value={a ? "TX-0654321" : "TX-0987654"} icon="filetext" />{a && <FieldRow label="License State" value="Texas" icon="shield" />}{!a && <FieldRow label="License Verified" value="Verified Feb 15, 2026" icon="check" />}<div style={{ padding: "14px 0 0" }}><p style={{ margin: 0, fontSize: 12, color: C.slateLight, fontWeight: 500 }}>Bio</p><p style={{ margin: "4px 0 0", fontSize: 14, color: C.navy, lineHeight: 1.5 }}>{a ? "Top-producing agent in Austin metro. 8 years experience." : "Licensed agent with photography and staging expertise."}</p></div></Card><div style={{ marginTop: 16 }}><Btn variant="primary" size="lg" full><Icon name="edit" size={16} color="#fff" /> Edit Information</Btn></div></div>); };
const PaymentScreen = ({ role }) => { const a = role === "agent"; return (<div style={{ padding: "0 20px 20px" }}><h2 style={{ margin: "20px 0 4px", fontSize: 22, fontWeight: 800, color: C.navy }}>{a ? "Payment Methods" : "Payout Settings"}</h2>{a ? [{ b: "Visa", l: "4829", e: "08/27", d: true }, { b: "MC", l: "1156", e: "03/28", d: false }].map((c, i) => <Card key={i} style={{ marginBottom: 10, padding: 16, display: "flex", alignItems: "center", gap: 14 }}><div style={{ width: 42, height: 42, borderRadius: 12, background: c.d ? C.blueLight : C.borderLight, display: "flex", alignItems: "center", justifyContent: "center" }}><Icon name="creditcard" size={20} color={c.d ? C.blue : C.slate} /></div><div style={{ flex: 1 }}><div style={{ display: "flex", alignItems: "center", gap: 8 }}><span style={{ fontWeight: 700, fontSize: 15, color: C.navy }}>{c.b} ····{c.l}</span>{c.d && <span style={{ fontSize: 11, fontWeight: 600, color: C.green, background: C.greenLight, padding: "2px 8px", borderRadius: 10 }}>Default</span>}</div><p style={{ margin: "2px 0 0", fontSize: 13, color: C.slateLight }}>Exp {c.e}</p></div></Card>) : <Card style={{ marginBottom: 10, padding: 16, display: "flex", alignItems: "center", gap: 14 }}><div style={{ width: 42, height: 42, borderRadius: 12, background: C.greenLight, display: "flex", alignItems: "center", justifyContent: "center" }}><Icon name="bank" size={20} color={C.green} /></div><div style={{ flex: 1 }}><span style={{ fontWeight: 700, fontSize: 15, color: C.navy }}>Chase ····6210</span><p style={{ margin: "2px 0 0", fontSize: 13, color: C.slateLight }}>Payouts every Friday</p></div></Card>}<Btn variant="secondary" size="lg" full style={{ marginTop: 6 }}><Icon name="plus" size={16} color={C.navy} /> {a ? "Add Payment Method" : "Add Payout Account"}</Btn></div>); };
const NotifSettingsScreen = ({ role }) => { const [s, setS] = useState({ tu: true, m: true, mk: false, p: true, nt: true, e: true }); const t = k => setS(p => ({ ...p, [k]: !p[k] })); const a = role === "agent"; return (<div style={{ padding: "0 20px 20px" }}><h2 style={{ margin: "20px 0 4px", fontSize: 22, fontWeight: 800, color: C.navy }}>Notification Settings</h2><Card><p style={{ margin: "0 0 10px", fontSize: 13, fontWeight: 700, color: C.navy }}>Push Notifications</p><ToggleRow label="Task Updates" on={s.tu} onToggle={() => t("tu")} /><ToggleRow label="Messages" on={s.m} onToggle={() => t("m")} /><ToggleRow label={a ? "Payment Confirmations" : "Payout Notifications"} on={s.p} onToggle={() => t("p")} />{!a && <ToggleRow label="New Available Tasks" on={s.nt} onToggle={() => t("nt")} />}{!a && <ToggleRow label="Weekly Earnings Summary" on={s.e} onToggle={() => t("e")} />}<ToggleRow label="Product Updates" on={s.mk} onToggle={() => t("mk")} /></Card></div>); };
const TaskHistoryScreen = ({ onTaskTap }) => (<div style={{ padding: "0 20px 20px" }}><h2 style={{ margin: "20px 0 4px", fontSize: 22, fontWeight: 800, color: C.navy }}>Task History</h2><Card style={{ marginBottom: 16, padding: 16 }}><div style={{ display: "flex", justifyContent: "space-between" }}><div><p style={{ margin: 0, fontSize: 12, color: C.slateLight }}>Total Spent</p><p style={{ margin: "2px 0 0", fontSize: 22, fontWeight: 800, color: C.navy }}>$1,235</p></div><div style={{ textAlign: "right" }}><p style={{ margin: 0, fontSize: 12, color: C.slateLight }}>Avg / Task</p><p style={{ margin: "2px 0 0", fontSize: 22, fontWeight: 800, color: C.navy }}>$176</p></div></div></Card><div style={{ display: "flex", flexDirection: "column", gap: 10 }}>{TASKS.map(t => <TaskCard key={t.id} task={t} onClick={() => onTaskTap(t)} showRunner />)}</div></div>);
const EarningsScreen = ({ onTaskTap }) => (<div style={{ padding: "0 20px 20px" }}><h2 style={{ margin: "20px 0 4px", fontSize: 22, fontWeight: 800, color: C.navy }}>Earnings & Payouts</h2><Card style={{ background: `linear-gradient(135deg, ${C.navy} 0%, ${C.navyMid} 100%)`, border: "none", marginBottom: 16, padding: 20 }}><div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 16 }}>{[{ l: "This Week", v: "$475" }, { l: "This Month", v: "$1,850" }, { l: "All Time", v: "$4,275" }, { l: "Tasks", v: "22" }].map(s => <div key={s.l}><p style={{ margin: 0, fontSize: 12, color: C.slateLight }}>{s.l}</p><p style={{ margin: "4px 0 0", fontSize: 28, fontWeight: 800, color: "#fff" }}>{s.v}</p></div>)}</div></Card><SectionHead title="Completed Tasks" /><div style={{ display: "flex", flexDirection: "column", gap: 10 }}>{RUNNER_HISTORY.map(t => <TaskCard key={t.id} task={t} onClick={() => onTaskTap(t)} showAgent />)}</div></div>);
const ServiceAreasScreen = () => (<div style={{ padding: "0 20px 20px" }}><h2 style={{ margin: "20px 0 4px", fontSize: 22, fontWeight: 800, color: C.navy }}>Service Areas</h2>{[{ a: "Downtown Austin", r: "5 mi", on: true }, { a: "South Austin", r: "8 mi", on: true }, { a: "East Austin", r: "6 mi", on: false }].map((a, i) => <Card key={i} style={{ padding: 16, marginBottom: 10, display: "flex", alignItems: "center", gap: 14 }}><div style={{ width: 42, height: 42, borderRadius: 12, background: a.on ? C.redLight : C.borderLight, display: "flex", alignItems: "center", justifyContent: "center" }}><Icon name="mappin" size={20} color={a.on ? C.red : C.slateLight} /></div><div style={{ flex: 1 }}><span style={{ fontWeight: 700, fontSize: 15, color: C.navy }}>{a.a}</span><p style={{ margin: "2px 0 0", fontSize: 13, color: C.slateLight }}>{a.r}</p></div><div style={{ width: 42, height: 26, borderRadius: 13, background: a.on ? C.green : C.border, display: "flex", alignItems: "center", padding: 2 }}><div style={{ width: 22, height: 22, borderRadius: 11, background: "#fff", transform: a.on ? "translateX(16px)" : "translateX(0)", transition: "transform 0.2s" }} /></div></Card>)}<Btn variant="secondary" size="lg" full><Icon name="plus" size={16} color={C.navy} /> Add Service Area</Btn></div>);
const AvailabilityScreen = () => (<div style={{ padding: "0 20px 20px" }}><h2 style={{ margin: "20px 0 4px", fontSize: 22, fontWeight: 800, color: C.navy }}>Availability</h2><Card>{["Mon","Tue","Wed","Thu","Fri","Sat","Sun"].map((d,i) => { const on = i < 6; return <div key={d} style={{ display: "flex", alignItems: "center", justifyContent: "space-between", padding: "12px 0", borderBottom: i < 6 ? `1px solid ${C.borderLight}` : "none" }}><div><span style={{ fontSize: 14, fontWeight: 600, color: on ? C.navy : C.slateLight }}>{d}</span><p style={{ margin: "2px 0 0", fontSize: 12, color: C.slateLight }}>{i < 5 ? "9 AM–6 PM" : i === 5 ? "10 AM–3 PM" : "Off"}</p></div><div style={{ width: 42, height: 26, borderRadius: 13, background: on ? C.green : C.border, display: "flex", alignItems: "center", padding: 2 }}><div style={{ width: 22, height: 22, borderRadius: 11, background: "#fff", transform: on ? "translateX(16px)" : "translateX(0)", transition: "transform 0.2s" }} /></div></div>; })}</Card></div>);
const SecurityScreen = ({ onSignOut }) => { const [showConfirm, setShowConfirm] = useState(false); return (<div style={{ padding: "0 20px 20px" }}><h2 style={{ margin: "20px 0 4px", fontSize: 22, fontWeight: 800, color: C.navy }}>Account & Security</h2><Card><MenuRow icon="mail" label="Change Email" /><MenuRow icon="shield" label="Change Password" /><MenuRow icon="phone" label="Two-Factor Auth" /><MenuRow icon="filetext" label="Privacy Policy" /><MenuRow icon="filetext" label="Terms of Service" last /></Card><div style={{ marginTop: 16 }}>{!showConfirm ? <Btn variant="secondary" size="lg" full style={{ color: C.errorRed, borderColor: C.errorRed }} onClick={() => setShowConfirm(true)}><Icon name="logout" size={16} color={C.errorRed} /> Sign Out</Btn> : <Card style={{ border: `1.5px solid ${C.errorRed}`, background: C.errorBg }}><p style={{ margin: "0 0 12px", fontSize: 15, fontWeight: 700, color: C.navy }}>Sign out of Agent Flo?</p><p style={{ margin: "0 0 16px", fontSize: 13, color: C.slate }}>You'll need to log in again to access your account.</p><div style={{ display: "flex", gap: 10 }}><Btn variant="secondary" size="md" style={{ flex: 1 }} onClick={() => setShowConfirm(false)}>Cancel</Btn><Btn variant="primary" size="md" style={{ flex: 1, background: C.errorRed }} onClick={onSignOut}>Sign Out</Btn></div></Card>}</div><p style={{ marginTop: 12, textAlign: "center", fontSize: 12, color: C.slateLight, cursor: "pointer" }}>Delete Account</p></div>); };

export default function Agent FloApp() {
  const [appPhase, setAppPhase] = useState("splash"); // splash → onboarding → app
  const [role, setRole] = useState("agent");
  const [tab, setTab] = useState("Dashboard");
  const [screen, setScreen] = useState(null);
  const [selectedTask, setSelectedTask] = useState(null);
  const [taskFilter, setTaskFilter] = useState(null);
  const [showSheet, setShowSheet] = useState(false);
  const [showFilter, setShowFilter] = useState(false);
  const [showLocPicker, setShowLocPicker] = useState(false);
  const [userLocation, setUserLocation] = useState("Austin, TX");
  const [mounted, setMounted] = useState(false);
  const [onboardDismissed, setOnboardDismissed] = useState(false);
  const [pendingTasks, setPendingTasks] = useState({});
  const [onboardSource, setOnboardSource] = useState(null); // "posted" | "drafted" | null

  useEffect(() => { setMounted(true); }, []);
  useEffect(() => {
    if (appPhase === "splash") { const t = setTimeout(() => setAppPhase("onboarding"), 2000); return () => clearTimeout(t); }
  }, [appPhase]);

  const handleGetStarted = (r, source) => { setRole(r); setAppPhase("app"); if (source) setOnboardSource(source); };
  const handleLogin = () => { setRole("agent"); setAppPhase("app"); };
  const handleSignOut = () => { setAppPhase("onboarding"); setScreen(null); setTab("Dashboard"); setOnboardDismissed(false); setPendingTasks({}); setUserLocation("Austin, TX"); setShowLocPicker(false); setOnboardSource(null); };
  const nav = s => setScreen(s);
  const deepLink = (targetTab, targetScreen) => { setTab(targetTab); setScreen(targetScreen || null); };
  const handleTaskTap = t => { setSelectedTask(t); setScreen("detail"); };
  const handleBack = () => { setScreen(null); setSelectedTask(null); setTaskFilter(null); };
  const handleRoleSwitch = () => { setRole(r => r === "agent" ? "runner" : "agent"); setScreen(null); setTab("Dashboard"); setOnboardDismissed(false); setPendingTasks({}); };
  const handleFilterTap = f => { setTaskFilter(f); setScreen("filtered"); };
  const handlePostTask = newTask => { setShowSheet(false); setSelectedTask(newTask); setScreen("detail"); };
  const handleAcceptTask = () => { if (selectedTask) setPendingTasks(p => ({ ...p, [selectedTask.id]: "pending" })); };
  const handleNotifTap = n => { const task = TASKS.find(t => t.id === n.taskId) || AVAILABLE.find(t => t.id === n.taskId); if (task) { setSelectedTask(task); setScreen(n.isMessage ? "chat" : "detail"); } };
  const handleChat = () => setScreen("chat");

  const titles = { personal: "Personal Information", payment: role === "agent" ? "Payment Methods" : "Payout Settings", notifSettings: "Notifications", history: role === "agent" ? "Task History" : "Earnings & Payouts", serviceAreas: "Service Areas", availability: "Availability", security: "Account & Security", detail: "Task Detail", chat: selectedTask ? `${selectedTask.runner || selectedTask.agent || "Chat"}` : "Chat", filtered: taskFilter === "all" ? "All Tasks" : taskFilter === "posted" ? "Posted" : taskFilter === "in_progress" ? "In Progress" : "Completed" };
  const title = titles[screen] || null;
  const onBack = screen ? (screen === "chat" ? () => setScreen("detail") : handleBack) : undefined;

  if (appPhase === "splash") return (<div style={{ minHeight: "100vh", display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", padding: "40px 20px", background: `linear-gradient(160deg, ${C.navy} 0%, #0F172A 40%, #1E293B 100%)`, fontFamily: "'DM Sans',sans-serif", opacity: mounted ? 1 : 0, transition: "opacity 0.6s" }}><link href="https://fonts.googleapis.com/css2?family=DM+Sans:wght@400;500;600;700;800&display=swap" rel="stylesheet" /><PhoneFrame hideNav><div style={{ minHeight: 756, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", background: C.white, gap: 16 }}><div style={{ width: 72, height: 72, borderRadius: 20, background: C.red, display: "flex", alignItems: "center", justifyContent: "center", boxShadow: "0 12px 32px rgba(200,16,46,0.3)" }}><span style={{ color: "#fff", fontWeight: 800, fontSize: 36 }}>A</span></div><h1 style={{ margin: 0, fontSize: 32, fontWeight: 800, color: C.navy, letterSpacing: -0.5 }}>Agent<span style={{ color: C.red }}>Assist</span></h1><div style={{ marginTop: 8 }}><div style={{ width: 32, height: 32, border: `3px solid ${C.borderLight}`, borderTopColor: C.red, borderRadius: "50%", animation: "spin 0.8s linear infinite" }} /><style>{`@keyframes spin{to{transform:rotate(360deg)}}`}</style></div></div></PhoneFrame></div>);

  if (appPhase === "onboarding") return (<div style={{ minHeight: "100vh", display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", padding: "40px 20px", background: `linear-gradient(160deg, ${C.navy} 0%, #0F172A 40%, #1E293B 100%)`, fontFamily: "'DM Sans',sans-serif" }}><link href="https://fonts.googleapis.com/css2?family=DM+Sans:wght@400;500;600;700;800&display=swap" rel="stylesheet" /><PhoneFrame hideNav><OnboardingFlow onComplete={handleGetStarted} onLogin={handleLogin} /></PhoneFrame><p style={{ marginTop: 24, color: C.slateLight, fontSize: 13 }}>Tap through the sign-up flow or Log In to skip</p></div>);

  return (<div style={{ minHeight: "100vh", display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", padding: "40px 20px", background: `linear-gradient(160deg, ${C.navy} 0%, #0F172A 40%, #1E293B 100%)`, fontFamily: "'DM Sans',sans-serif" }}><link href="https://fonts.googleapis.com/css2?family=DM+Sans:wght@400;500;600;700;800&display=swap" rel="stylesheet" /><div style={{ textAlign: "center", marginBottom: 32 }}><div style={{ display: "flex", alignItems: "center", justifyContent: "center", gap: 10, marginBottom: 8 }}><div style={{ width: 36, height: 36, borderRadius: 10, background: C.red, display: "flex", alignItems: "center", justifyContent: "center" }}><span style={{ color: "#fff", fontWeight: 800, fontSize: 18 }}>A</span></div><h1 style={{ margin: 0, color: "#fff", fontSize: 28, fontWeight: 800, letterSpacing: -0.5 }}>Agent<span style={{ color: C.red }}>Assist</span></h1></div><p style={{ margin: 0, color: C.slateLight, fontSize: 15 }}>Viewing as: <strong style={{ color: "#fff" }}>{role === "agent" ? "Agent" : "Task Runner"}</strong><span style={{ marginLeft: 12, fontSize: 12, padding: "3px 10px", borderRadius: 10, background: "rgba(255,255,255,0.08)", color: C.slateLight }}>iOS 26 · Liquid Glass</span></p></div>
    <PhoneFrame title={title} onBack={onBack} rightAction={!screen && tab === "Dashboard" && role === "agent" ? <div onClick={() => setShowSheet(true)} style={{ cursor: "pointer", padding: 4 }}><Icon name="plus" size={22} color={C.red} /></div> : null}>
      {screen === "detail" ? <TaskDetail task={selectedTask} role={role} onChat={handleChat} onAccept={handleAcceptTask} taskStatus={pendingTasks[selectedTask?.id]} />
      : screen === "chat" ? <ChatView task={selectedTask} role={role} />
      : screen === "filtered" ? <FilteredTaskList filter={taskFilter} onTaskTap={handleTaskTap} />
      : screen === "personal" ? <PersonalInfoScreen role={role} />
      : screen === "payment" ? <PaymentScreen role={role} />
      : screen === "notifSettings" ? <NotifSettingsScreen role={role} />
      : screen === "history" ? (role === "agent" ? <TaskHistoryScreen onTaskTap={handleTaskTap} /> : <EarningsScreen onTaskTap={handleTaskTap} />)
      : screen === "serviceAreas" ? <ServiceAreasScreen />
      : screen === "availability" ? <AvailabilityScreen />
      : screen === "security" ? <SecurityScreen onSignOut={handleSignOut} />
      : tab === "Dashboard" ? (role === "agent" ? <AgentDash onTaskTap={handleTaskTap} onCreateTask={() => setShowSheet(true)} onboardDismissed={onboardDismissed} onDismissOnboard={() => setOnboardDismissed(true)} onFilterTap={handleFilterTap} onboardSource={onboardSource} onDismissSource={() => setOnboardSource(null)} onProfileStep={(s) => deepLink("Profile", s)} onViewNewTask={() => { setOnboardSource(null); handleTaskTap({ id: 99, type: "Photography", address: "1234 New Listing Dr, Austin TX", price: 150, status: onboardSource === "posted" ? "posted" : "draft", time: "Tomorrow, 10:00 AM", runner: null, desc: "New task from onboarding." }); }} /> : <RunnerDash onTaskTap={handleTaskTap} onOpenFilter={() => setShowFilter(true)} userLocation={userLocation} onChangeLoc={() => setShowLocPicker(true)} />)
      : tab === "Notifications" ? <NotificationsScreen onNotifTap={handleNotifTap} onSettings={() => deepLink("Profile", "notifSettings")} />
      : <ProfileHome role={role} onRoleSwitch={handleRoleSwitch} onNavigate={nav} />}
      <GlassTabBar activeTab={tab} onTabChange={t => { setTab(t); setScreen(null); }} notifCount={NOTIFS.filter(n => !n.read).length} />
      {showSheet && <SheetModal onClose={() => setShowSheet(false)}><TaskCreationSheet onClose={() => setShowSheet(false)} onPost={handlePostTask} /></SheetModal>}
      {showFilter && <SheetModal onClose={() => setShowFilter(false)}><FilterSheet onClose={() => setShowFilter(false)} userLocation={userLocation} /></SheetModal>}
      {showLocPicker && <SheetModal onClose={() => setShowLocPicker(false)}><LocationPicker current={userLocation} onSelect={setUserLocation} onClose={() => setShowLocPicker(false)} /></SheetModal>}
    </PhoneFrame>
    <p style={{ marginTop: 24, color: C.slateLight, fontSize: 13 }}>Interactive prototype — tap around to explore flows</p></div>);
}

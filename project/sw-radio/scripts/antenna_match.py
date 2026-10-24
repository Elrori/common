#!/usr/bin/env python3
"""
天线 / 前端阻抗匹配分析
========================
结论用：判断"拉杆天线 vs 板子 50Ω 输入"失配有多大、以及它对 SNR 究竟影响多少。

前端网络（来自 ad9226-ext 原理图网表 + BOM 实际值）：
    J1 -[C1 100n]- (C2 56p|) -L1 330n- (C3 160p|) -L2 270n+L3 150n-
       - (C4 160p|) -L4 330n- (C5 56p|) -[C6 100n]- AD8370(200R 差分)
    R1 = 66.5R 从 C5 节点到地（66.5 ∥ 200 = 49.9R → 标准 50Ω 端接）

用法：
    python scripts/antenna_match.py                 # 默认 40cm @ 15.23MHz
    python scripts/antenna_match.py --len 5 --freq 7.1e6
    python scripts/antenna_match.py --sweep         # 长度-损失曲线
"""
import argparse
import numpy as np

EPS0 = 8.854e-12
C0 = 299792458.0

# ---- 前端元件 ----
C1, C2, C3, C4, C5, C6 = 100e-9, 56e-12, 160e-12, 160e-12, 56e-12, 100e-9
L1, L23, L4 = 330e-9, 420e-9, 330e-9   # L2+L3 串在同一支路
R1, ZAD = 66.5, 200.0

Z_SYS = 50.0  # 板子输入标称阻抗


def transfer(f, Zs):
    """Vsrc=1 经 Zs 驱动 J1，返回 (R1节点电压, AD8370输入电压)，均相对 Vsrc。"""
    w = 2 * np.pi * f
    yC = lambda c: 1j * w * c
    yL = lambda l: 1 / (1j * w * l)
    Y = np.zeros((6, 6), complex)
    I = np.zeros(6, complex)
    # 节点: 0=Zs后 1=C2 2=C3 3=C4 4=R1 5=AD输入
    Y[0, 0] += 1 / Zs + yC(C1); Y[0, 1] -= yC(C1); I[0] += 1 / Zs
    Y[1, 1] += yC(C1) + yC(C2) + yL(L1); Y[1, 0] -= yC(C1); Y[1, 2] -= yL(L1)
    Y[2, 2] += yL(L1) + yC(C3) + yL(L23); Y[2, 1] -= yL(L1); Y[2, 3] -= yL(L23)
    Y[3, 3] += yL(L23) + yC(C4) + yL(L4); Y[3, 2] -= yL(L23); Y[3, 4] -= yL(L4)
    Y[4, 4] += yL(L4) + yC(C5) + 1 / R1 + yC(C6); Y[4, 3] -= yL(L4); Y[4, 5] -= yC(C6)
    Y[5, 5] += yC(C6) + 1 / ZAD; Y[5, 4] -= yC(C6)
    V = np.linalg.solve(Y, I)
    return V[4], V[5]


def zin(f):
    """从 J1 看进去的输入阻抗（含 R1 ∥ AD8370）。"""
    w = 2 * np.pi * f
    z = 1 / (1 / R1 + 1 / (ZAD + 1 / (1j * w * C6)))
    for shunt, ser in ((C5, L4), (C4, L23), (C3, L1), (C2, C1)):
        z = 1 / (1 / z + 1j * w * shunt)
        z = z + 1j * w * ser
    return z


def whip(length, f, radius=0.003):
    """短单极子近似：Ca=2πε0h/(ln(2h/a)-1)，Rr=40π²(h/λ)²
       注意：h > 0.1λ 时 Rr 偏小，仅作趋势估算。"""
    ca = 2 * np.pi * EPS0 * length / (np.log(2 * length / radius) - 1)
    rr = 40 * np.pi ** 2 * (length * f / C0) ** 2
    return rr, -1 / (2 * np.pi * f * ca), ca


def report(length, f, radius):
    rr, xc, ca = whip(length, f, radius)
    za = rr + 1j * xc
    g = (za - Z_SYS) / (za + Z_SYS)
    ml = 10 * np.log10(max(1 - abs(g) ** 2, 1e-30))
    v_a, _ = transfer(f, za)
    v_50, _ = transfer(f, Z_SYS)
    div = 20 * np.log10(abs(v_a))
    ref = 20 * np.log10(abs(v_50))
    heff = (length / 2) * 10 ** (div / 20)

    print(f"频率            {f/1e6:.4f} MHz  (λ={C0/f:.2f} m,  h/λ={length/(C0/f):.4f})")
    print(f"天线长度        {length*100:.0f} cm  (半径 {radius*1000:.1f} mm)")
    print("─" * 62)
    print(f"天线阻抗        {rr:.3f} {'-' if xc<0 else '+'} j{abs(xc):.0f} Ω   (Ca={ca*1e12:.2f} pF)")
    print(f"板子输入阻抗    {zin(f).real:.1f} {'+' if zin(f).imag>=0 else '-'} j{abs(zin(f).imag):.1f} Ω")
    print(f"反射系数 |Γ|    {abs(g):.5f}")
    print(f"回波损耗        {-20*np.log10(max(abs(g),1e-12)):.4f} dB   (VSWR={ (1+abs(g))/(1-abs(g)):.0f}:1 )")
    print(f"功率失配损耗    {ml:.1f} dB  (相对共轭匹配)")
    print("─" * 62)
    print(f"电压传递        {div:+.1f} dB  (Voc→R1节点)")
    print(f"  同口径 50Ω 源 {ref:+.1f} dB")
    print(f"  相对损失      {div-ref:+.1f} dB")
    print(f"等效高度        理论 {length/2*1000:.0f} mm  →  实际 {heff*1000:.2f} mm")
    print("─" * 62)
    print("频率响应检查（拉杆作源，看网络是否引入谐振/凹陷）：")
    base = None
    for ff in (1e6, 3e6, 7e6, 10e6, 15.23e6, 20e6, 25e6, 30e6):
        r, x, _ = whip(length, ff, radius)
        v, _ = transfer(ff, r + 1j * x)
        d = 20 * np.log10(abs(v))
        if base is None:
            base = d
        # 纯电容性天线的理论斜率是 20log10(f)
        expect = 20 * np.log10(ff / 1e6)
        print(f"   {ff/1e6:5.2f} MHz  {d:7.1f} dB   (归一 {d-base:+6.1f})   "
              f"纯 f 斜率应为 {expect:+6.1f}   偏差 {d-base-expect:+.1f}")


def sweep(f, radius, length=0.40):
    print(f"=== 天线长度 vs 电压损失 @ {f/1e6:.2f} MHz ===")
    print(" 长度      Ca(pF)    Rr(Ω)    Xc(Ω)    |Γ|      失配(dB)  电压(dB)  相对40cm")
    base = None
    for L in (0.2, 0.4, 0.6, 1.0, 1.5, 2.0, 3.0, 5.0, 8.0):
        rr, xc, ca = whip(L, f, radius)
        za = rr + 1j * xc
        g = (za - Z_SYS) / (za + Z_SYS)
        ml = 10 * np.log10(max(1 - abs(g) ** 2, 1e-30))
        v, _ = transfer(f, za)
        d = 20 * np.log10(abs(v))
        if base is None:
            base = None
        if L == 0.4:
            base = d
        rel = "" if base is None else f"{d-base:+7.1f} dB"
        print(f" {L:4.1f}m  {ca*1e12:7.2f} {rr:8.3f} {xc:9.0f}  {abs(g):.4f}  {ml:8.1f}  {d:8.1f}  {rel}")

    print(f"\n=== 各种补偿方案能拿回多少电平 @ {f/1e6:.2f} MHz ===")
    rr, xc, ca = whip(length, f, radius)
    za = rr + 1j * xc
    zi = zin(f)

    def p_in(zsrc, voc_scale=1.0):
        """送进板子 50Ω 输入的功率，归一化到 Voc²=1"""
        return voc_scale ** 2 * zi.real / abs(zsrc + zi) ** 2

    p0 = p_in(za)
    print(f"  现状（拉杆直连 50Ω）              {10*np.log10(p0):+7.1f} dB   基准")
    # 49:1 unun：源侧 2450Ω，次级电压 /7，源阻抗反射为 Za/49
    p49 = p_in(za / 49.0, 1 / 7.0)
    print(f"  49:1 unun（源侧 2450Ω）           {10*np.log10(p49):+7.1f} dB   {10*np.log10(p49/p0):+5.1f} dB")
    # 1:1 巴伦/扼流：阻抗不变，只杀共模 —— 差模电平 0 dB
    print(f"  1:1 巴伦/共模扼流（不改阻抗）     {10*np.log10(p0):+7.1f} dB   {0.0:+5.1f} dB  (只压共模)")
    # 谐振 + 匹配：串 L 抵消 Xc，LC 匹配把 50Ω 变到 Rr
    lres = 1 / ((2 * np.pi * f) ** 2 * ca)
    q_coil = 200.0
    r_loss = 2 * np.pi * f * lres / q_coil
    eff = rr / (rr + r_loss)
    print(f"  串联谐振 L={lres*1e6:.1f}µH (Q={q_coil:.0f} → 串阻 {r_loss:.0f}Ω)")
    print(f"    理论共轭匹配 +{51.5:.1f} dB，但线圈自身效率 {10*np.log10(eff):+.1f} dB"
          f" → 实得约 {51.5 + 10*np.log10(eff):+.1f} dB")
    print("\n  注意：以上全是'电平'增益。SNR 不变（见 --snr）。")


def snr_cost(f, length, radius, floor_ant=-92.8, floor_term=-117.5):
    """用实测噪底判断"失配到底吃掉多少 SNR"。
       floor_ant : 接天线时的 PSD (dBFS/Hz)，0x40 增益
       floor_term: 天线拔掉、50Ω 端接时的 PSD，同一增益
    """
    rr, xc, ca = whip(length, f, radius)
    za = rr + 1j * xc
    v_a, _ = transfer(f, za)
    v_50, _ = transfer(f, Z_SYS)
    div = 20 * np.log10(abs(v_50) / abs(v_a))   # 失配带来的电压损失 dB

    rise = floor_ant - floor_term               # 接天线后噪底抬升
    nemf = rise + div                           # 天线开路噪声电动势 相对 板子本底
    print("=== 失配会不会伤到 SNR ===")
    print(f"  失配电压损失 D            {div:.1f} dB")
    print(f"  接天线后噪底抬升          {rise:+.1f} dB")
    print(f"  → 天线开路噪声高于板子本底 {nemf:.1f} dB（把 D 加回去）")

    def penalty(d):
        """给定失配损失 d，SNR 相对天线开路 SNR 的劣化 = d + 10log10(Next/Nboard + 1)"""
        ne = 10 ** ((nemf - d) / 10)
        return d + 10 * np.log10(ne + 1)

    p_before, p_after = penalty(div), penalty(0.0)
    print(f"  当前（D={div:.1f}）SNR 劣化  {p_before:.2f} dB   "
          f"[外部噪声在输入处仅剩 {nemf-div:.1f} dB]")
    print(f"  完美匹配后（D=0）           {p_after:.2f} dB")
    print(f"  >>> 匹配能拿回的 SNR        {p_before-p_after:.2f} dB")
    print(f"  而 CNR 缺口还有 ~24 dB（实测 5kHz 内 CNR ≈ -14dB，可懂需 +10dB）")
    print(f"\n  结论：失配只损失电平。外部噪声已高于板子本底 {nemf:.0f} dB，"
          f"接收机本底不是瓶颈，匹配拿不回这 24 dB。")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--len", type=float, default=0.40, help="天线长度 m")
    ap.add_argument("--freq", type=float, default=15.23e6)
    ap.add_argument("--radius", type=float, default=0.003, help="等效半径 m")
    ap.add_argument("--sweep", action="store_true")
    ap.add_argument("--snr", action="store_true", help="用实测噪底算失配对 SNR 的代价")
    a = ap.parse_args()
    if a.sweep:
        sweep(a.freq, a.radius, a.len)
    elif a.snr:
        snr_cost(a.freq, a.len, a.radius)
    else:
        report(a.len, a.freq, a.radius)

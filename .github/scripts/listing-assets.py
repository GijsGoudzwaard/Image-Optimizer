#!/usr/bin/env python3
"""Bouwt exports zoals ze uit een ontwerpprogramma komen: veel vorm, weinig
kleur, als 24 bits png weggeschreven. Via MVG, want de shell struikelde over het
aanhalen van honderden draw opdrachten.

Er wordt niets voorgekookt. De app doet straks het echte werk en de getallen in
de opname zijn wat hij haalde; dit maakt alleen de bestanden.
"""
import os
import shutil
import subprocess

W = "/tmp/assets"
shutil.rmtree(W, ignore_errors=True)
os.makedirs(W)


def render(name, width, height, body, background="#ffffff"):
    mvg = ["viewbox 0 0 %d %d" % (width, height),
           "fill '%s'" % background,
           "rectangle 0,0 %d,%d" % (width - 1, height - 1)]
    mvg += body
    path = "/tmp/draw.mvg"
    open(path, "w").write("\n".join(mvg) + "\n")
    subprocess.run(
        ["convert", "-size", "%dx%d" % (width, height), "mvg:" + path,
         "-define", "png:color-type=2", "-depth", "8",
         "PNG24:" + os.path.join(W, name)],
        check=True,
    )


def ui(name, w, h, accent):
    """Zijbalk, koptekst en een tabel met veel rijen."""
    b = ["fill '%s'" % accent, "rectangle 0,0 %d,140" % (w - 1),
         "fill '#f4f5fb'", "rectangle 0,140 %d,%d" % (w // 5, h - 1)]

    y = 200
    while y < h - 80:
        b += ["fill '#ffffff'",
              "roundrectangle 40,%d %d,%d 10,10" % (y, w // 5 - 40, y + 52),
              "fill '%s'" % accent,
              "circle 72,%d 72,%d" % (y + 26, y + 8),
              "fill '#dfe3f6'",
              "roundrectangle 110,%d %d,%d 8,8" % (y + 18, w // 5 - 70, y + 34)]
        y += 68

    y = 220
    while y < h - 60:
        b += ["fill '#dfe3f6'",
              "rectangle %d,%d %d,%d" % (w // 5 + 60, y + 40, w - 60, y + 41),
              "fill '#2b2b30'",
              "roundrectangle %d,%d %d,%d 6,6" % (w // 5 + 60, y + 14, w // 5 + 460, y + 30),
              "fill '#74747e'",
              "roundrectangle %d,%d %d,%d 6,6" % (w - 900, y + 14, w - 700, y + 30),
              "roundrectangle %d,%d %d,%d 6,6" % (w - 620, y + 14, w - 420, y + 30),
              "fill '#1D9E75'",
              "roundrectangle %d,%d %d,%d 6,6" % (w - 340, y + 14, w - 200, y + 30)]
        y += 52

    render(name, w, h, b)


def icon_set(name):
    b = []
    i = 0
    for row in range(6):
        for col in range(9):
            x, y = col * 256 + 128, row * 256 + 128
            shape = i % 4
            if shape == 0:
                b += ["fill '#687ddb'",
                      "roundrectangle %d,%d %d,%d 32,32" % (x - 88, y - 88, x + 88, y + 88)]
            elif shape == 1:
                b += ["fill '#1D9E75'", "circle %d,%d %d,%d" % (x, y, x, y - 88)]
            elif shape == 2:
                b += ["fill '#A32D2D'",
                      "roundrectangle %d,%d %d,%d 20,20" % (x - 88, y - 56, x + 88, y + 56)]
            else:
                b += ["fill '#2b2b30'",
                      "polygon %d,%d %d,%d %d,%d" % (x, y - 88, x + 88, y + 88, x - 88, y + 88)]
            b += ["fill '#ffffff'", "circle %d,%d %d,%d" % (x, y, x, y - 24)]
            i += 1
    render(name, 2304, 1536, b, background="#f4f5fb")


def chart(name):
    b = []
    x = 200
    for i in range(1, 25):
        top = 200 + (i * 137) % 700
        b += ["fill '#687ddb'", "rectangle %d,%d %d,1200" % (x, top, x + 90),
              "fill '#dfe3f6'", "rectangle %d,%d %d,%d" % (x, top - 20, x + 90, top - 6)]
        x += 120
    b += ["fill '#2b2b30'", "rectangle 200,1200 3100,1206"]
    render(name, 3200, 1400, b)


def logo(name, background, mark):
    b = ["fill '%s'" % mark, "roundrectangle 200,380 1000,620 40,40",
         "fill '#687ddb'", "circle 1400,500 1400,260",
         "fill '%s'" % mark, "roundrectangle 1700,430 2800,570 20,20"]
    render(name, 3000, 1000, b, background=background)


# Een map met exports zoals die er aan het eind van een release uitziet: een
# stel opnames op retinamaat, een icoonblad, wat diagrammen en de logo's. De
# maten verschillen per bestand, want dat doen ze in het echt ook.
shots = [
    # Groot en vroeg in het alfabet, zodat er in de opname ook een rij is die nog
    # bezig is: de workers pakken de lijst in volgorde en deze duurt het langst.
    ("app-hero-render@4x.png", 6144, 4096, "#687ddb"),
    ("screenshot-dashboard@3x.png", 5120, 3200, "#687ddb"),
    ("screenshot-reports@3x.png", 4992, 3120, "#687ddb"),
    ("screenshot-inbox@3x.png", 4096, 3072, "#687ddb"),
    ("screenshot-calendar@3x.png", 4160, 3008, "#687ddb"),
    ("screenshot-settings@2x.png", 3072, 2304, "#5a6fd0"),
    ("screenshot-profile@2x.png", 2944, 2208, "#5a6fd0"),
    ("appstore-6.7-inch-1.png", 2778, 1284, "#687ddb"),
    ("appstore-6.7-inch-2.png", 2778, 1284, "#5a6fd0"),
    ("appstore-6.7-inch-3.png", 2778, 1284, "#687ddb"),
    ("appstore-5.5-inch-1.png", 2208, 1242, "#687ddb"),
    ("appstore-5.5-inch-2.png", 2208, 1242, "#5a6fd0"),
    ("play-feature-graphic.png", 4096, 2304, "#687ddb"),
    ("onboarding-1@2x.png", 2560, 1600, "#687ddb"),
    ("onboarding-2@2x.png", 2560, 1600, "#5a6fd0"),
    ("onboarding-3@2x.png", 2560, 1600, "#687ddb"),
    ("empty-state-inbox.png", 2048, 1536, "#687ddb"),
    ("empty-state-search.png", 2048, 1536, "#5a6fd0"),
]
for name, w, h, accent in shots:
    ui(name, w, h, accent)

icon_set("icon-set@3x.png")
icon_set("icon-set@2x.png")
chart("chart-quarterly.png")
chart("chart-yearly.png")
chart("chart-retention.png")
logo("logo-wordmark.png", "#ffffff", "#2b2b30")
logo("logo-wordmark-dark.png", "#16162e", "#ffffff")
logo("social-card.png", "#f4f5fb", "#2b2b30")

print("=== wat de app hier echt op haalt ===")
total_before = total_after = 0
for name in sorted(os.listdir(W)):
    path = os.path.join(W, name)
    before = os.path.getsize(path)
    shutil.copy(path, "/tmp/probe.png")
    subprocess.run(["optipng", "-o3", "-strip", "all", "-preserve", "-quiet", "/tmp/probe.png"])
    after = os.path.getsize("/tmp/probe.png")
    os.remove("/tmp/probe.png")
    print("%-32s %9d -> %9d  %6.2f%%" % (name, before, after, (1 - after / before) * 100))
    total_before += before
    total_after += after

print()
print("totaal: %.2f MB -> %.2f MB, %.1f%% kleiner"
      % (total_before / 1e6, total_after / 1e6, (1 - total_after / total_before) * 100))

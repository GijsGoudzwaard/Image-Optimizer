#!/usr/bin/env python3
"""Shrinks an Inkscape SVG without changing a single rendered pixel.

Removes three kinds of dead weight and nothing else:

  1. <metadata> and <sodipodi:namedview>, which no renderer reads.
  2. every attribute in the inkscape: and sodipodi: namespaces.
  3. gradient definitions that no reference can reach, worked out
     transitively over both url(#id) and xlink:href="#id", because Inkscape
     chains a gradient carrying the stops to a second one carrying the
     coordinates.

Paths, coordinates, precision, colours and reachable gradients are left
untouched, so the drawing instructions are identical.
"""
import re, sys

SVG = "http://www.w3.org/2000/svg"
XLINK = "http://www.w3.org/1999/xlink"
INK = "http://www.inkscape.org/namespaces/inkscape"
SODI = "http://sodipodi.sourceforge.net/DTD/sodipodi-0.0.dtd"

import xml.etree.ElementTree as ET


def parents(root):
    return {c: p for p in root.iter() for c in p}


def referenced_ids(root):
    """Every id reachable from a url(#..) or xlink:href="#..", transitively."""
    by_id = {el.get("id"): el for el in root.iter() if el.get("id")}
    seen = set()
    queue = []

    for el in root.iter():
        for name, value in el.attrib.items():
            if name == "{%s}href" % XLINK and value.startswith("#"):
                # only follow hrefs from elements that are themselves used
                continue
            for ref in re.findall(r"url\(#([^)]+)\)", value or ""):
                queue.append(ref)

    while queue:
        ref = queue.pop()
        if ref in seen:
            continue
        seen.add(ref)
        el = by_id.get(ref)
        if el is None:
            continue
        # follow this element's own references onwards
        for name, value in el.attrib.items():
            if name == "{%s}href" % XLINK and (value or "").startswith("#"):
                queue.append(value[1:])
            for r in re.findall(r"url\(#([^)]+)\)", value or ""):
                queue.append(r)
        for child in el.iter():
            for name, value in child.attrib.items():
                if name == "{%s}href" % XLINK and (value or "").startswith("#"):
                    queue.append(value[1:])
                for r in re.findall(r"url\(#([^)]+)\)", value or ""):
                    queue.append(r)
    return seen


def strip(src, dst):
    ET.register_namespace("", SVG)
    ET.register_namespace("xlink", XLINK)

    tree = ET.parse(src)
    root = tree.getroot()

    keep = referenced_ids(root)

    pmap = parents(root)
    for el in list(root.iter()):
        tag = el.tag
        if tag in ("{%s}metadata" % SVG, "{%s}namedview" % SODI):
            pmap.get(el) is not None and pmap[el].remove(el)

    # opnieuw, want de boom is veranderd
    pmap = parents(root)
    for el in list(root.iter()):
        if el.tag in ("{%s}linearGradient" % SVG, "{%s}radialGradient" % SVG):
            if el.get("id") not in keep and el in pmap:
                pmap[el].remove(el)

    for el in root.iter():
        for name in list(el.attrib):
            if name.startswith("{%s}" % INK) or name.startswith("{%s}" % SODI):
                del el.attrib[name]

    tree.write(dst, encoding="UTF-8", xml_declaration=True)

    data = open(dst, encoding="utf-8").read()
    for prefix, uri in (("inkscape", INK), ("sodipodi", SODI),
                        ("dc", "http://purl.org/dc/elements/1.1/"),
                        ("cc", "http://creativecommons.org/ns#"),
                        ("rdf", "http://www.w3.org/1999/02/22-rdf-syntax-ns#")):
        decl = ' xmlns:%s="%s"' % (prefix, uri)
        if decl in data and ("%s:" % prefix) not in data.replace(decl, ""):
            data = data.replace(decl, "")
    open(dst, "w", encoding="utf-8").write(data)


if __name__ == "__main__":
    strip(sys.argv[1], sys.argv[2])

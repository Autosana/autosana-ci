#!/usr/bin/env python3
"""Check a mobile build before it uploads, and read its bundle ID or package name.

    python3 check_build.py <android|ios> <path>

Exits 0 printing the build's bundle ID or package name (an empty line when it can't be
read), or exits 2 printing why the build can never run. Any other exit means the check
itself failed, and the upload goes ahead unchecked. Only the standard library is used,
and only the start and end of the build are read.
"""

from __future__ import annotations

import plistlib
import re
import struct
import sys
import zipfile
from pathlib import PurePosixPath

REFUSED = 2

APK_MANIFEST = "AndroidManifest.xml"
# An .aab keeps its manifest as aapt2's protobuf XmlNode, not binary XML.
AAB_MANIFEST = "base/manifest/AndroidManifest.xml"
# What Android installs: two or more dot-separated segments, each starting with a letter.
PACKAGE_NAME = re.compile(r"[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z][A-Za-z0-9_]*)+")

CPU_TYPE_X86_64 = 0x01000007
CPU_TYPE_ARM64 = 0x0100000C


class Refused(Exception):
    """A build that can never run, with what to do about it."""


def main(platform: str, path: str) -> int:
    try:
        build_id = android(path) if platform.lower() == "android" else ios(path)
    except Refused as refusal:
        print(refusal)
        return REFUSED
    print(build_id or "")
    return 0


# --- Archives ---


def starts_with(path: str, prefix: bytes) -> bool:
    with open(path, "rb") as file:
        return file.read(len(prefix)) == prefix


def looks_like_text(path: str) -> bool:
    with open(path, "rb") as file:
        head = file.read(512)
    return all(byte >= 0x20 or byte in (0x09, 0x0A, 0x0D) for byte in head)


def not_a_zip(path: str) -> Refused:
    """A build that must be a zip but isn't: cut off before its end, or not an archive at all."""
    if starts_with(path, b"PK\x03\x04"):
        return Refused("The build is cut off before its end, so it can't be installed. Export or download it again.")
    return Refused(
        "The build isn't an app build. If it was downloaded, it may be an error page saved under "
        "the build's name: download the build again."
    )


# --- Android ---


def android(path: str) -> str | None:
    try:
        with zipfile.ZipFile(path) as archive:
            names = set(archive.namelist())
            if APK_MANIFEST in names:
                manifest, read_package = archive.read(APK_MANIFEST), binary_manifest_package
            elif AAB_MANIFEST in names:
                manifest, read_package = archive.read(AAB_MANIFEST), proto_manifest_package
            else:
                raise Refused("The build has no AndroidManifest.xml, so it isn't an Android app. Upload your .apk.")
    except zipfile.BadZipFile:
        raise not_a_zip(path) from None
    try:
        package = read_package(manifest)
    except (struct.error, IndexError, UnicodeDecodeError, ValueError):
        return None
    return package if package and PACKAGE_NAME.fullmatch(package) else None


def binary_manifest_package(data: bytes) -> str | None:
    """`<manifest package>` from an .apk's binary XML: the string pool, then the first element's attributes."""
    strings: list[str] = []
    offset = struct.unpack_from("<H", data, 2)[0]
    while offset + 8 <= len(data):
        kind, header_size, size = struct.unpack_from("<HHI", data, offset)
        if size < 8:
            return None
        if kind == 0x0001:
            strings = string_pool(data, offset, header_size)
        elif kind == 0x0102:
            first, attribute_size, count = struct.unpack_from("<HHH", data, offset + header_size + 8)
            for index in range(count):
                at = offset + header_size + first + index * attribute_size
                _ns, name, raw, _size, _zero, value_type, value = struct.unpack_from("<IIIHBBI", data, at)
                if strings[name] == "package":
                    if raw != 0xFFFFFFFF:
                        return strings[raw]
                    return strings[value] if value_type == 0x03 else None
            return None
        offset += size
    return None


def string_pool(data: bytes, chunk: int, header_size: int) -> list[str]:
    count, _styles, flags, strings_start = struct.unpack_from("<IIII", data, chunk + 8)
    utf8 = bool(flags & 0x100)
    strings = []
    for index in range(count):
        at = chunk + strings_start + struct.unpack_from("<I", data, chunk + header_size + 4 * index)[0]
        if utf8:
            _, at = pool_length(data, at, wide=False)  # the length in UTF-16 units, which UTF-8 doesn't need
            length, at = pool_length(data, at, wide=False)
            strings.append(data[at : at + length].decode("utf-8"))
        else:
            length, at = pool_length(data, at, wide=True)
            strings.append(data[at : at + 2 * length].decode("utf-16-le"))
    return strings


def pool_length(data: bytes, at: int, *, wide: bool) -> tuple[int, int]:
    """A string length, one or two units long (the high bit of the first says two), and where the text starts."""
    unit, high = (2, 0x8000) if wide else (1, 0x80)
    first = int.from_bytes(data[at : at + unit], "little")
    if first & high:
        second = int.from_bytes(data[at + unit : at + 2 * unit], "little")
        return ((first & (high - 1)) << (8 * unit)) | second, at + 2 * unit
    return first, at + unit


def proto_fields(message: bytes) -> list[tuple[int, bytes]]:
    """One protobuf message's length-delimited fields, as (field number, bytes); other wire types are skipped."""
    fields, at = [], 0

    def varint() -> int:
        nonlocal at
        value = shift = 0
        while True:
            byte = message[at]
            at += 1
            value |= (byte & 0x7F) << shift
            if not byte & 0x80:
                return value
            shift += 7
            if shift > 63:
                raise ValueError("bad protobuf varint")

    while at < len(message):
        tag = varint()
        wire_type = tag & 7
        if wire_type == 0:
            varint()
        elif wire_type == 1:
            at += 8
        elif wire_type == 5:
            at += 4
        elif wire_type == 2:
            length = varint()
            if at + length > len(message):
                raise ValueError("truncated protobuf field")
            fields.append((tag >> 3, message[at : at + length]))
            at += length
        else:
            raise ValueError(f"unsupported protobuf wire type {wire_type}")
    return fields


def proto_string(fields: list[tuple[int, bytes]], number: int) -> str | None:
    return next((value.decode("utf-8") for field, value in fields if field == number), None)


def proto_manifest_package(data: bytes) -> str | None:
    """`<manifest package>` from an .aab's protobuf XML: XmlNode.element (1) -> XmlElement.name (3)
    and .attribute (4) -> XmlAttribute.name (2) and .value (3)."""
    element = next((value for field, value in proto_fields(data) if field == 1), None)
    if element is None:
        return None
    fields = proto_fields(element)
    if proto_string(fields, 3) != "manifest":
        return None
    for field, attribute in fields:
        attribute_fields = proto_fields(attribute) if field == 4 else []
        if proto_string(attribute_fields, 2) == "package":
            return proto_string(attribute_fields, 3)
    return None


# --- iOS ---


def ios(path: str) -> str | None:
    is_ipa = path.lower().endswith(".ipa")
    try:
        with zipfile.ZipFile(path) as archive:
            names = archive.namelist()
            plist = app_info_plist(names)
            if plist is None:
                if is_ipa:
                    return None
                raise Refused("The zip has no .app inside. Zip the Simulator .app itself and upload that.")
            info = plistlib.loads(archive.read(plist))
            if is_ipa:
                return bundle_id(info)
            if platform_of(info) == "iphoneos":
                raise Refused(
                    "This is a device build, which can't run on the iOS Simulator. Build for a Simulator "
                    "destination and upload that .app (zipped), or upload an .ipa to test on real iPhones."
                )
            executable = info.get("CFBundleExecutable")
            binary = str(PurePosixPath(plist).parent / executable) if isinstance(executable, str) else None
            if binary in names and intel_only(zip_head(archive, binary)):
                raise Refused(
                    "This Simulator build only has Intel (x86_64) code, and Autosana's Simulators run on Apple "
                    "silicon. Build it for arm64 too: make sure EXCLUDED_ARCHS doesn't exclude arm64 for the "
                    "Simulator, then build for 'generic/platform=iOS Simulator'."
                )
            return bundle_id(info)
    except zipfile.BadZipFile:
        # Simulator builds also run from other archives (Expo's are gzip tarballs named .zip), so only
        # a cut-off zip or a text file, often an error page saved under the build's name, is refused.
        if starts_with(path, b"PK\x03\x04") or looks_like_text(path):
            raise not_a_zip(path) from None
        return None
    except (plistlib.InvalidFileException, ValueError, KeyError):
        return None


def app_info_plist(names: list[str]) -> str | None:
    """The `<App>.app/Info.plist` closest to the root, ignoring Finder's `__MACOSX/` copies."""
    plists = [
        name
        for name in names
        if not name.startswith("__MACOSX/") and re.search(r"(^|/)[^/]+\.app/Info\.plist$", name)
    ]
    return min(plists, key=lambda name: name.count("/"), default=None)


def platform_of(info: dict) -> str:
    platform = str(info.get("DTPlatformName") or "").lower()
    supported = [str(p).lower() for p in info.get("CFBundleSupportedPlatforms") or []]
    return platform or next((p for p in supported if p in {"iphonesimulator", "iphoneos"}), "")


def bundle_id(info: dict) -> str | None:
    value = info.get("CFBundleIdentifier")
    return value if isinstance(value, str) else None


def zip_head(archive: zipfile.ZipFile, name: str) -> bytes:
    """The first 4 KB of an archive member, inflating no more of it."""
    with archive.open(name) as member:
        return member.read(4096)


def mach_o_cpu_types(head: bytes) -> list[int]:
    """The CPU types a Mach-O binary holds, from its first bytes: one when thin, each slice's when fat."""
    if len(head) < 8:
        return []
    (fat_magic,) = struct.unpack_from(">I", head)
    if fat_magic in (0xCAFEBABE, 0xCAFEBABF):
        record = 32 if fat_magic == 0xCAFEBABF else 20
        count = min(struct.unpack_from(">I", head, 4)[0], (len(head) - 8) // record)
        return [struct.unpack_from(">I", head, 8 + i * record)[0] for i in range(count)]
    thin_magic, cpu_type = struct.unpack_from("<II", head)
    return [cpu_type] if thin_magic in (0xFEEDFACF, 0xFEEDFACE) else []


def intel_only(head: bytes) -> bool:
    types = mach_o_cpu_types(head)
    return CPU_TYPE_X86_64 in types and CPU_TYPE_ARM64 not in types


if __name__ == "__main__":
    sys.exit(main(sys.argv[1], sys.argv[2]))

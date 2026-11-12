/// <reference types="@raycast/api">

/* 🚧 🚧 🚧
 * This file is auto-generated from the extension's manifest.
 * Do not modify manually. Instead, update the `package.json` file.
 * 🚧 🚧 🚧 */

/* eslint-disable @typescript-eslint/ban-types */

type ExtensionPreferences = {
  /** Target Display - Name of the display Toggle HDR should act on. Leave empty to use the first external HDR-capable display. */
  "displayName"?: string
}

/** Preferences accessible in all the extension's commands */
declare type Preferences = ExtensionPreferences

declare namespace Preferences {
  /** Preferences accessible in the `toggle-hdr` command */
  export type ToggleHdr = ExtensionPreferences & {}
  /** Preferences accessible in the `menu-bar` command */
  export type MenuBar = ExtensionPreferences & {}
  /** Preferences accessible in the `hdr-on-connect` command */
  export type HdrOnConnect = ExtensionPreferences & {}
  /** Preferences accessible in the `watch-displays` command */
  export type WatchDisplays = ExtensionPreferences & {}
}

declare namespace Arguments {
  /** Arguments passed to the `toggle-hdr` command */
  export type ToggleHdr = {}
  /** Arguments passed to the `menu-bar` command */
  export type MenuBar = {}
  /** Arguments passed to the `hdr-on-connect` command */
  export type HdrOnConnect = {}
  /** Arguments passed to the `watch-displays` command */
  export type WatchDisplays = {}
}

declare module "swift:*/swift" {
  export function listDisplays(): Promise<any[]>;
  export function setHdr(displayID: number, value: string): Promise<boolean>;

  export class SwiftError extends Error {
    stderr: string;
    stdout: string;
  }
}
// Copy this file to config.h (gitignored -- it holds your WiFi password)
// and fill in your values before flashing.
#ifndef CONFIG_H
#define CONFIG_H

#define WIFI_SSID       "your-wifi-ssid"
#define WIFI_PASSWORD   "your-wifi-password"

// Stable identifier this camera reports in every /status response, so the
// Hub's camera registry (meridian_hub/capture/camera_registry.py) can map
// it to a room/resident regardless of what IP DHCP hands out. Matches the
// PRD's camera_id field (section 15.1, section 17 event schema).
#define CAMERA_ID       "cam-room-101"

// VGA (640x480) is the documented real-world sweet spot for this sensor
// over WiFi -- higher resolutions cause severe frame drops on the OV2640's
// 2.4GHz-only radio. Matches the PRD section 14.1 prototype target.
#define FRAME_SIZE      FRAMESIZE_VGA
#define JPEG_QUALITY    12   // 0-63, lower = higher quality/larger frames

#endif

# Bill of Materials

Main hardware used for the Pink Selfie Camera ESP32 project.

| Part                         | Purpose              | Notes                                                     |
| ---------------------------- | -------------------- | --------------------------------------------------------- |
| Seeed XIAO ESP32S3 Sense     | Main microcontroller | Runs the camera firmware, Wi-Fi server, and microSD logic |
| OV3660 camera module         | Camera sensor        | Used for live preview and photo/video capture             |
| Seeed Round Display for XIAO | Camera screen        | Shows the live round preview                              |
| microSD card                 | Local storage        | Stores captured photos and videos                         |
| LiPo battery                 | Portable power       | Powers the camera without USB                             |
| Slide power switch           | Power control        | Used to turn the camera on/off                            |
| 3D printed front shell       | Enclosure            | Custom designed in OpenSCAD                               |
| 3D printed back cover        | Enclosure            | Covers electronics and battery                            |
| Screws / brass inserts       | Assembly             | Used to close the enclosure                               |
| Small wires                  | Internal wiring      | Used for battery and switch connections                   |
| Heat tape / insulation tape  | Safety               | Covers solder joints and prevents shorts                  |

## Notes

This project is built as a compact prototype, so the internal space is limited. The battery, switch, display, camera module, and wiring all need to fit inside the 3D printed enclosure.

The exact battery size and screw lengths may need small adjustments depending on the final case version and 3D print tolerances.
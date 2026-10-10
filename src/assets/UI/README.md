# Tiny Factory Figma UI artwork

Source: https://www.figma.com/design/FOimGQRxpMOrVO3uX5zilP/Tiny-Factory-UI

The PNGs are the original Figma exports. AmberUI reproduces the individual image-fill rectangles without drawing replacement icons. Figma exports are retained here as source assets; Rojo uses the uploaded Roblox IDs through AmberUI.

| Export | Roblox image | Uploaded pixels |
| --- | --- | --- |
| frames.png | 71291524765168 | 682 x 1023 |
| buttons.png | 120956512848045 | 682 x 1023 |
| icons.png | 91445651094912 | 682 x 1023 |
| roll.png | 137411904241513 | 498 x 276 |

The image permissions include the Tiny Factory universe 10767190926. Original sheets are 1024 x 1536; the Roll control has a 249 x 138 logical rectangle exported at double resolution. Roblox texture coordinates must account for these sizes.

Production uses ordinary image assets. Studio uses four cached, unmodified EditableImages to avoid cached legacy image permission failures in the connected Studio session. No pixels are changed. Machine thumbnails use the same shared native model builder as the factory.

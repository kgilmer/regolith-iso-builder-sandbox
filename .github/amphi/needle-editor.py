#!/usr/bin/env python3
"""Visual needle editor — draw match/exclude regions on a needle PNG and save the JSON.

Usage:
    ./needle-editor.py needles/setup-welcome.png
    ./needle-editor.py needles/setup-welcome      # .png is added automatically

Controls:
    Left-click + drag   Draw a new match region (green)
    Right-click + drag  Draw a new exclude region (red)
    Click on region     Select it (highlighted with handles)
    Delete / Backspace  Remove selected region
    +/-                 Adjust match threshold of selected region (+/- 5)
    Ctrl+S              Save JSON
    Ctrl+Z              Undo last action
    Escape              Deselect / quit if nothing selected
"""

import json
import os
import sys
import tkinter as tk
from tkinter import messagebox

try:
    from PIL import Image, ImageTk
except ImportError:
    print("ERROR: Pillow is required. Install with: pip install Pillow", file=sys.stderr)
    sys.exit(1)


class Region:
    """A match or exclude region."""
    def __init__(self, rtype, x, y, w, h, match=85):
        self.type = rtype  # "match" or "exclude"
        self.x = x
        self.y = y
        self.w = w
        self.h = h
        self.match = match  # only meaningful for "match" type

    def to_dict(self):
        d = {
            "type": self.type,
            "xpos": self.x,
            "ypos": self.y,
            "width": self.w,
            "height": self.h,
        }
        if self.type == "match":
            d["match"] = self.match
        return d

    @staticmethod
    def from_dict(d):
        return Region(
            rtype=d["type"],
            x=d["xpos"],
            y=d["ypos"],
            w=d["width"],
            h=d["height"],
            match=d.get("match", 85),
        )


class NeedleEditor:
    def __init__(self, root, png_path):
        self.root = root
        self.png_path = png_path
        self.json_path = os.path.splitext(png_path)[0] + ".json"
        self.tag = os.path.splitext(os.path.basename(png_path))[0]

        # Load image
        self.pil_image = Image.open(png_path)
        self.img_w, self.img_h = self.pil_image.size
        self.tk_image = ImageTk.PhotoImage(self.pil_image)

        # State
        self.regions = []
        self.selected_idx = None
        self.drag_start = None
        self.drag_rect_id = None
        self.drag_button = None
        self.undo_stack = []
        self.dirty = False

        # Load existing JSON if present
        if os.path.exists(self.json_path):
            self._load_json()

        # UI setup
        self.root.title(f"Needle Editor — {self.tag}")
        self.root.resizable(False, False)

        # Info bar
        self.info_frame = tk.Frame(root)
        self.info_frame.pack(side=tk.TOP, fill=tk.X, padx=4, pady=2)
        self.info_label = tk.Label(self.info_frame, text="", anchor=tk.W)
        self.info_label.pack(side=tk.LEFT)
        self.save_btn = tk.Button(self.info_frame, text="Save (Ctrl+S)", command=self.save_json)
        self.save_btn.pack(side=tk.RIGHT)

        # Canvas
        self.canvas = tk.Canvas(root, width=self.img_w, height=self.img_h,
                                cursor="crosshair")
        self.canvas.pack()
        self.canvas.create_image(0, 0, anchor=tk.NW, image=self.tk_image)

        # Help bar
        help_text = ("Left-drag: match region | Right-drag: exclude region | "
                     "Del: remove | +/-: threshold | Ctrl+S: save | Ctrl+Z: undo")
        tk.Label(root, text=help_text, fg="gray40", font=("monospace", 9)).pack(
            side=tk.BOTTOM, fill=tk.X, padx=4, pady=2)

        # Bindings
        self.canvas.bind("<ButtonPress-1>", self._on_press)
        self.canvas.bind("<B1-Motion>", self._on_drag)
        self.canvas.bind("<ButtonRelease-1>", self._on_release)
        self.canvas.bind("<ButtonPress-3>", self._on_press)
        self.canvas.bind("<B3-Motion>", self._on_drag)
        self.canvas.bind("<ButtonRelease-3>", self._on_release)
        self.root.bind("<Delete>", self._on_delete)
        self.root.bind("<BackSpace>", self._on_delete)
        self.root.bind("<plus>", self._on_threshold_up)
        self.root.bind("<equal>", self._on_threshold_up)
        self.root.bind("<minus>", self._on_threshold_down)
        self.root.bind("<Control-s>", lambda e: self.save_json())
        self.root.bind("<Control-z>", lambda e: self.undo())
        self.root.bind("<Escape>", self._on_escape)
        self.root.protocol("WM_DELETE_WINDOW", self._on_close)

        self._redraw()

    def _load_json(self):
        with open(self.json_path) as f:
            data = json.load(f)
        self.regions = [Region.from_dict(a) for a in data.get("area", [])]
        tag = data.get("tags", [self.tag])
        if tag:
            self.tag = tag[0]

    def _save_snapshot(self):
        """Push current state onto undo stack."""
        self.undo_stack.append([
            Region(r.type, r.x, r.y, r.w, r.h, r.match) for r in self.regions
        ])
        if len(self.undo_stack) > 50:
            self.undo_stack.pop(0)

    def undo(self):
        if not self.undo_stack:
            return
        self.regions = self.undo_stack.pop()
        self.selected_idx = None
        self.dirty = True
        self._redraw()

    def save_json(self):
        data = {
            "area": [r.to_dict() for r in self.regions],
            "tags": [self.tag],
            "properties": [],
        }
        with open(self.json_path, "w") as f:
            json.dump(data, f, indent=2)
            f.write("\n")
        self.dirty = False
        self._update_info()
        self.root.title(f"Needle Editor — {self.tag}")

    def _redraw(self):
        """Redraw all region rectangles on the canvas."""
        self.canvas.delete("region")
        for i, r in enumerate(self.regions):
            selected = (i == self.selected_idx)
            if r.type == "match":
                outline = "#00ff00" if not selected else "#00ff88"
                dash = ()
            else:
                outline = "#ff0000" if not selected else "#ff6666"
                dash = (4, 4)
            width = 3 if selected else 2
            self.canvas.create_rectangle(
                r.x, r.y, r.x + r.w, r.y + r.h,
                outline=outline, width=width, dash=dash, tags="region"
            )
            # Label
            label = r.type[0].upper()
            if r.type == "match":
                label += f" {r.match}%"
            self.canvas.create_text(
                r.x + 4, r.y + 2, text=label, anchor=tk.NW,
                fill=outline, font=("monospace", 10, "bold"), tags="region"
            )
        self._update_info()

    def _update_info(self):
        n_match = sum(1 for r in self.regions if r.type == "match")
        n_excl = sum(1 for r in self.regions if r.type == "exclude")
        status = f"Tag: {self.tag}  |  {n_match} match, {n_excl} exclude regions"
        if self.selected_idx is not None:
            r = self.regions[self.selected_idx]
            status += f"  |  Selected: {r.type} ({r.x},{r.y} {r.w}x{r.h}"
            if r.type == "match":
                status += f" match={r.match}%"
            status += ")"
        if self.dirty:
            status += "  [unsaved]"
        self.info_label.config(text=status)

    def _hit_test(self, x, y):
        """Return index of region under (x,y), or None."""
        for i in range(len(self.regions) - 1, -1, -1):
            r = self.regions[i]
            if r.x <= x <= r.x + r.w and r.y <= y <= r.y + r.h:
                return i
        return None

    def _on_press(self, event):
        self.drag_button = event.num  # 1=left, 3=right
        self.drag_start = (event.x, event.y)
        self.drag_rect_id = None
        # Check if clicking an existing region to select it
        hit = self._hit_test(event.x, event.y)
        if hit is not None and self.drag_button == 1:
            self.selected_idx = hit
            self._redraw()

    def _on_drag(self, event):
        if self.drag_start is None:
            return
        sx, sy = self.drag_start
        x, y = event.x, event.y
        # Only start drawing if dragged more than 5px (avoid accidental micro-drags)
        if abs(x - sx) < 5 and abs(y - sy) < 5:
            return
        if self.drag_rect_id:
            self.canvas.delete(self.drag_rect_id)
        color = "#00ff00" if self.drag_button == 1 else "#ff0000"
        dash = () if self.drag_button == 1 else (4, 4)
        self.drag_rect_id = self.canvas.create_rectangle(
            sx, sy, x, y, outline=color, width=2, dash=dash
        )

    def _on_release(self, event):
        if self.drag_start is None:
            return
        sx, sy = self.drag_start
        x, y = event.x, event.y
        if self.drag_rect_id:
            self.canvas.delete(self.drag_rect_id)
            self.drag_rect_id = None

        # Only create region if dragged far enough
        if abs(x - sx) >= 5 and abs(y - sy) >= 5:
            self._save_snapshot()
            rtype = "match" if self.drag_button == 1 else "exclude"
            rx = min(sx, x)
            ry = min(sy, y)
            rw = abs(x - sx)
            rh = abs(y - sy)
            # Clamp to image bounds
            rx = max(0, min(rx, self.img_w))
            ry = max(0, min(ry, self.img_h))
            rw = min(rw, self.img_w - rx)
            rh = min(rh, self.img_h - ry)
            region = Region(rtype, rx, ry, rw, rh)
            self.regions.append(region)
            self.selected_idx = len(self.regions) - 1
            self.dirty = True
            self._redraw()

        self.drag_start = None
        self.drag_button = None

    def _on_delete(self, event):
        if self.selected_idx is not None and 0 <= self.selected_idx < len(self.regions):
            self._save_snapshot()
            del self.regions[self.selected_idx]
            self.selected_idx = None
            self.dirty = True
            self._redraw()

    def _on_threshold_up(self, event):
        if self.selected_idx is not None:
            r = self.regions[self.selected_idx]
            if r.type == "match":
                self._save_snapshot()
                r.match = min(100, r.match + 5)
                self.dirty = True
                self._redraw()

    def _on_threshold_down(self, event):
        if self.selected_idx is not None:
            r = self.regions[self.selected_idx]
            if r.type == "match":
                self._save_snapshot()
                r.match = max(0, r.match - 5)
                self.dirty = True
                self._redraw()

    def _on_escape(self, event):
        if self.selected_idx is not None:
            self.selected_idx = None
            self._redraw()
        else:
            self._on_close()

    def _on_close(self):
        if self.dirty:
            if messagebox.askyesno("Unsaved changes", "Save before closing?"):
                self.save_json()
        self.root.destroy()


def main():
    if len(sys.argv) < 2:
        print("Usage: needle-editor.py <needle-png-or-name>", file=sys.stderr)
        print("  e.g.: ./needle-editor.py needles/setup-welcome.png", file=sys.stderr)
        print("        ./needle-editor.py needles/setup-welcome", file=sys.stderr)
        sys.exit(1)

    path = sys.argv[1]
    if not path.endswith(".png"):
        path += ".png"
    if not os.path.exists(path):
        print(f"ERROR: File not found: {path}", file=sys.stderr)
        sys.exit(1)

    root = tk.Tk()
    NeedleEditor(root, path)
    root.mainloop()


if __name__ == "__main__":
    main()

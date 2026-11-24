#!/usr/bin/env python3
# Thin wrapper: the real script is skills/video-knowledge-distill/check_notes.py, so the
# two copies can never drift apart.
# 正本在 skills/video-knowledge-distill/check_notes.py，这里只是转过去，免得两份改得不一样。
import os, runpy
runpy.run_path(os.path.join(os.path.dirname(os.path.abspath(__file__)), "skills", "video-knowledge-distill", "check_notes.py"), run_name="__main__")

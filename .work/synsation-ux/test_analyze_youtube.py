import json
import tempfile
import unittest
from pathlib import Path

import analyze_youtube


class YoutubeWorkflowTests(unittest.TestCase):
    def test_url_normalization(self):
        expected = ("https://www.youtube.com/watch?v=c-G-p7REUd0", "c-G-p7REUd0")
        for value in (
            "https://www.youtube.com/watch?v=c-G-p7REUd0&utm_source=test",
            "https://youtu.be/c-G-p7REUd0?t=5",
            "https://m.youtube.com/shorts/c-G-p7REUd0",
        ):
            self.assertEqual(analyze_youtube.normalize_youtube_url(value), expected)

    def test_manifest_deduplicates_by_video_id(self):
        video = {
            "title": "test",
            "category": "test",
            "series_part": None,
            "original_url": "https://youtu.be/c-G-p7REUd0",
            "canonical_url": "https://www.youtube.com/watch?v=c-G-p7REUd0",
            "video_id": "c-G-p7REUd0",
        }
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "manifest.json"
            path.write_text(json.dumps({"video_count": 1, "videos": [video, video]}), encoding="utf-8")
            self.assertEqual(len(analyze_youtube.load_manifest(path)), 1)

    def test_real_manifest_has_24_unique_valid_videos(self):
        path = Path(analyze_youtube.__file__).with_name("youtube-videos.json")
        videos = analyze_youtube.load_manifest(path)
        self.assertEqual(len(videos), 24)
        self.assertEqual(sum(item.get("pilot") is True for item in videos), 1)


if __name__ == "__main__":
    unittest.main()

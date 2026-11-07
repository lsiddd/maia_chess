"""Regression coverage for overlapping nightly builds of the same commit."""
import unittest

from check_nightly_order import should_publish


class NightlyOrderTests(unittest.TestCase):
    def test_first_nightly_can_publish(self):
        self.assertTrue(should_publish(10, ""))

    def test_late_older_build_cannot_replace_newer_apk(self):
        self.assertFalse(should_publish(10, "<!-- maia-nightly-build: 11 -->"))

    def test_newer_build_can_replace_published_apk(self):
        self.assertTrue(should_publish(12, "<!-- maia-nightly-build: 11 -->"))

    def test_same_build_can_retry_partial_publication(self):
        self.assertTrue(should_publish(11, "<!-- maia-nightly-build: 11 -->"))

    def test_migrates_existing_nightly_notes(self):
        notes = "Automated build.\n\n- Version: 1.0.0 (build 31)\n- CI: run 31\n"
        self.assertFalse(should_publish(30, notes))
        self.assertTrue(should_publish(32, notes))

    def test_marker_takes_priority_over_display_notes(self):
        notes = "- Version: 1.0.0 (build 10)\n<!-- maia-nightly-build: 11 -->"
        self.assertFalse(should_publish(10, notes))

    def test_unknown_metadata_fails_without_replacing_release(self):
        with self.assertRaisesRegex(ValueError, "no readable build number"):
            should_publish(12, "A nightly with unknown provenance.")

    def test_build_number_must_be_positive(self):
        with self.assertRaises(ValueError):
            should_publish(0, "")


if __name__ == "__main__":
    unittest.main()

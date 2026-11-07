import json
import subprocess
import unittest
from datetime import date
from unittest.mock import patch

import project_burndown as burndown


class SprintWindowsTest(unittest.TestCase):
    def test_s3_has_four_weeks_from_each_teams_s2_close(self):
        for team, start, end, weekday in (
            ("INT2", "2026-11-04", "2026-12-02", 2),
            ("INT4", "2026-11-05", "2026-12-03", 3),
        ):
            for scope in ("Equipo", "Integrante"):
                rows = [{
                    "snapshot_date": "2026-11-06",
                    "sprint": "S3",
                    "scope": scope,
                    "key": team if scope == "Equipo" else "member",
                    "equipo": team,
                }]
                first, last = burndown.chart_window(rows, None, None)
                self.assertEqual(first, date.fromisoformat(start))
                self.assertEqual(last, date.fromisoformat(end))
                self.assertEqual(first, burndown.configured_team_window(team, "S2")[1])
                self.assertEqual((last - first).days, 28)
                self.assertEqual(first.weekday(), weekday)
                self.assertEqual(last.weekday(), weekday)

    def test_s3_is_accepted_by_each_daily_command(self):
        parser = burndown.build_parser()
        for command in ("capture", "render", "all"):
            self.assertEqual(parser.parse_args([command]).sprint, "S3")
            self.assertEqual(parser.parse_args([command, "--sprint", "S3"]).sprint, "S3")

    def test_s2_has_five_weeks_and_each_teams_own_dates(self):
        for team, start, end in (
            ("INT2", "2026-09-30", "2026-11-04"),
            ("INT4", "2026-10-01", "2026-11-05"),
        ):
            rows = [{
                "snapshot_date": "2026-10-03",
                "sprint": "S2",
                "scope": "Equipo",
                "key": team,
            }]
            first, last = burndown.chart_window(rows, None, None)
            self.assertEqual(first, date.fromisoformat(start))
            self.assertEqual(last, date.fromisoformat(end))
            self.assertEqual((last - first).days, 35)

    def test_historical_s1_members_keep_the_original_window(self):
        for team, start, end in (
            ("INT2", "2026-09-02", "2026-09-30"),
            ("INT4", "2026-09-03", "2026-10-01"),
        ):
            rows = [{
                "snapshot_date": "2026-09-30",
                "sprint": "S1",
                "scope": "Integrante",
                "key": "member",
                "equipo": team,
            }]
            self.assertEqual(
                burndown.chart_window(rows, None, None),
                (date.fromisoformat(start), date.fromisoformat(end)),
            )

    def test_incomplete_project_capture_is_rejected(self):
        payload = {"totalCount": 204, "items": [{}] * 200}
        result = subprocess.CompletedProcess([], 0, stdout=json.dumps(payload))
        with patch.object(burndown.subprocess, "run", return_value=result):
            with self.assertRaisesRegex(SystemExit, "incompleta"):
                burndown.fetch_project("cchelooo", 2, 200)


if __name__ == "__main__":
    unittest.main()

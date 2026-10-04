import json
import subprocess
import unittest
from datetime import date
from unittest.mock import patch

import project_burndown as burndown


class SprintWindowsTest(unittest.TestCase):
    def test_s2_has_four_weeks_and_each_teams_own_dates(self):
        for team, start, end in (
            ("INT2", "2026-09-30", "2026-10-28"),
            ("INT4", "2026-10-01", "2026-10-29"),
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
            self.assertEqual((last - first).days, 28)

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

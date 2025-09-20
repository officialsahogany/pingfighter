import unittest

from soldier.controller import SoldierWeaponController


class SoldierWeaponControllerTest(unittest.TestCase):
    def setUp(self) -> None:
        self.controller = SoldierWeaponController()

    def test_add_weapon_updates_inventory_and_highlight(self) -> None:
        added = self.controller.add_weapon("bazooka")
        self.assertTrue(added)
        self.assertIn("bazooka", self.controller.weapons)
        self.assertEqual(self.controller.current_index, len(self.controller.weapons) - 1)
        self.assertGreater(self.controller.ui_highlight_timer, 0)

    def test_register_reload_marks_degraded(self) -> None:
        self.controller.add_weapon("ak47")
        for _ in range(3):
            self.controller.register_reload("ak47")
        self.assertIn("ak47", self.controller.degraded)

    def test_remove_weapon_falls_back_to_pistol(self) -> None:
        self.controller.add_weapon("net_gun")
        self.controller.remove_weapon("net_gun")
        self.assertEqual(self.controller.weapons, ["pistol"])
        self.assertEqual(self.controller.current_index, 0)


if __name__ == "__main__":  # pragma: no cover - manual execution helper
    unittest.main()

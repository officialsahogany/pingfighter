import unittest

from soldier.controller import SoldierWeaponController


class SoldierWeaponControllerTest(unittest.TestCase):
    def setUp(self) -> None:
        self.controller = SoldierWeaponController()

    def test_add_rental_weapon_updates_inventory_and_highlight(self) -> None:
        added = self.controller.add_weapon("bazooka")

        self.assertTrue(added)
        self.assertIn("bazooka", self.controller.weapons)
        self.assertTrue(self.controller.is_rental_weapon("bazooka"))
        self.assertEqual(self.controller.current_index, len(self.controller.weapons) - 1)
        self.assertGreater(self.controller.ui_highlight_timer, 0)

    def test_unlock_permanent_weapon_rebuilds_equipped_inventory(self) -> None:
        added = self.controller.unlock_permanent_weapon("ak47")

        self.assertTrue(added)
        self.controller.set_equipped_permanent(["ak47"], set_active="ak47")

        self.assertIn("ak47", self.controller.permanent_owned)
        self.assertIn("ak47", self.controller.weapons)
        self.assertFalse(self.controller.is_rental_weapon("ak47"))
        self.assertEqual(self.controller.current_weapon(), "ak47")

    def test_remove_expired_rentals_keeps_only_current_stage_weapons(self) -> None:
        self.controller.grant_rental_weapon("net_gun", acquired_stage=2, set_active=False)
        self.controller.grant_rental_weapon("fire_support", acquired_stage=3, set_active=False)

        removed = self.controller.remove_expired_rentals(3)

        self.assertEqual(removed, ["net_gun"])
        self.assertNotIn("net_gun", self.controller.weapons)
        self.assertIn("fire_support", self.controller.weapons)

    def test_remove_weapon_falls_back_to_pistol(self) -> None:
        self.controller.add_weapon("net_gun")
        self.controller.remove_weapon("net_gun")

        self.assertEqual(self.controller.weapons, ["pistol"])
        self.assertEqual(self.controller.current_index, 0)


if __name__ == "__main__":  # pragma: no cover - manual execution helper
    unittest.main()

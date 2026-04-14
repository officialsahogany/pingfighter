import unittest

from events import weather_event as weather_module


class TestWeatherEventParticles(unittest.TestCase):
    def tearDown(self):
        weather_module.reset_weather_state()

    def test_rain_does_not_spawn_wind_particles(self):
        weather_module.reset_weather_state()
        weather_module.weather_event_active = True
        weather_module.weather_event_type = "rain"
        weather_module.weather_event_direction = 0

        for _ in range(12):
            weather_module.update_weather_particles(1280, 720)

        self.assertEqual(weather_module.weather_particles, [])

    def test_breeze_still_spawns_wind_particles(self):
        weather_module.reset_weather_state()
        weather_module.weather_event_active = True
        weather_module.weather_event_type = "breeze"
        weather_module.weather_event_direction = 1

        for _ in range(6):
            weather_module.update_weather_particles(1280, 720)

        self.assertGreater(len(weather_module.weather_particles), 0)


if __name__ == "__main__":
    unittest.main()

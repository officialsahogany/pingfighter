    def _draw_branch_skill_tree(self, tree_data, cost_scaling):
        skill_size = 60
        row_spacing = 140
        col_spacing = 200

        tree_width = col_spacing * 2
        available_width = self.width - 190
        start_x = (available_width - tree_width) // 2 + 30
        start_y = 160

        skill_positions: dict[str, tuple[int, int]] = {}
        for skill in tree_data["skills"]:
            row = skill["row"]
            col = skill["col"]
            if col == 0.5:
                x = start_x + col_spacing // 2
            else:
                x = start_x + int(col) * col_spacing
            y = start_y + row * row_spacing
            skill_positions[skill["id"]] = (x, y)

        for skill in tree_data["skills"]:
            current_pos = skill_positions[skill["id"]]
            tp_requirement = skill.get("total_tp_required", 0)
            tp_met = self.skill_system.total_invested_points >= tp_requirement

            requires = skill.get("requires")
            if requires:
                if isinstance(requires, list):
                    for required_skill in requires:
                        if required_skill in skill_positions:
                            required_pos = skill_positions[required_skill]
                            required_level = self.skill_system.get_skill_level(required_skill)
                            line_color = (100, 255, 100) if (required_level > 0 and tp_met) else (100, 100, 100)
                            pygame.draw.line(
                                self.screen,
                                line_color,
                                (required_pos[0] + skill_size // 2, required_pos[1] + skill_size),
                                (current_pos[0] + skill_size // 2, current_pos[1]),
                                3,
                            )
                            pygame.draw.polygon(
                                self.screen,
                                line_color,
                                [
                                    (current_pos[0] + skill_size // 2, current_pos[1]),
                                    (current_pos[0] + skill_size // 2 - 8, current_pos[1] - 15),
                                    (current_pos[0] + skill_size // 2 + 8, current_pos[1] - 15),
                                ],
                            )
                            self.draw_arrow_animation(required_skill, skill["id"])
                else:
                    if requires in skill_positions:
                        required_pos = skill_positions[requires]
                        required_level = self.skill_system.get_skill_level(requires)
                        line_color = (100, 255, 100) if (required_level > 0 and tp_met) else (100, 100, 100)
                        pygame.draw.line(
                            self.screen,
                            line_color,
                            (required_pos[0] + skill_size // 2, required_pos[1] + skill_size),
                            (current_pos[0] + skill_size // 2, current_pos[1]),
                            3,
                        )
                        pygame.draw.polygon(
                            self.screen,
                            line_color,
                            [
                                (current_pos[0] + skill_size // 2, current_pos[1]),
                                (current_pos[0] + skill_size // 2 - 8, current_pos[1] - 15),
                                (current_pos[0] + skill_size // 2 + 8, current_pos[1] - 15),
                            ],
                        )
                        self.draw_arrow_animation(requires, skill["id"])

            requires_or = skill.get("requires_or")
            if requires_or:
                for required_skill in requires_or:
                    if required_skill in skill_positions:
                        required_pos = skill_positions[required_skill]
                        required_level = self.skill_system.get_skill_level(required_skill)
                        line_color = (100, 255, 100) if (required_level > 0 and tp_met) else (100, 100, 100)
                        pygame.draw.line(
                            self.screen,
                            line_color,
                            (required_pos[0] + skill_size // 2, required_pos[1] + skill_size),
                            (current_pos[0] + skill_size // 2, current_pos[1]),
                            3,
                        )
                        pygame.draw.polygon(
                            self.screen,
                            line_color,
                            [
                                (current_pos[0] + skill_size // 2, current_pos[1]),
                                (current_pos[0] + skill_size // 2 - 8, current_pos[1] - 15),
                                (current_pos[0] + skill_size // 2 + 8, current_pos[1] - 15),
                            ],
                        )
                        self.draw_arrow_animation(required_skill, skill["id"])

        for i, skill in enumerate(tree_data["skills"]):
            skill_x, skill_y = skill_positions[skill["id"]]

            if i == self.selected_skill_index and not self.tab_selection_mode:
                highlight_rect = pygame.Rect(skill_x - 5, skill_y - 5, skill_size + 10, skill_size + 10)
                pygame.draw.rect(self.screen, (100, 100, 150, 50), highlight_rect)
                pygame.draw.rect(self.screen, (255, 255, 255), highlight_rect, 2)

            current_level = self.skill_system.get_skill_level(skill["id"])

            if i == self.selected_skill_index and not self.tab_selection_mode:
                pulse = abs(math.sin(pygame.time.get_ticks() * 0.005)) * 0.5 + 0.5
                select_size = skill_size + int(8 + pulse * 5)
                pygame.draw.circle(
                    self.screen,
                    (0, 255, 255),
                    (skill_x + skill_size // 2, skill_y + skill_size // 2),
                    select_size,
                    3,
                )
                angle = pygame.time.get_ticks() * 0.002
                hex_points = []
                for j in range(6):
                    hex_angle = angle + j * math.pi / 3
                    hx = skill_x + skill_size // 2 + (skill_size + 12) * math.cos(hex_angle)
                    hy = skill_y + skill_size // 2 + (skill_size + 12) * math.sin(hex_angle)
                    hex_points.append((hx, hy))
                pygame.draw.polygon(self.screen, (0, 255, 255, 100), hex_points, 2)

            icon = self.create_skill_icon(skill, current_level, skill["max_level"], skill_size)
            self.screen.blit(icon, (skill_x, skill_y))

            if skill["id"] in self.skill_levelup_animations:
                anim_data = self.skill_levelup_animations[skill["id"]]
                current_time = pygame.time.get_ticks()
                elapsed = current_time - anim_data["start_time"]
                if elapsed < anim_data["duration"]:
                    progress = elapsed / anim_data["duration"]
                    center_x = skill_x + skill_size // 2
                    center_y = skill_y + skill_size // 2
                    if elapsed < 50:
                        flash_alpha = int(120 * (1 - elapsed / 50))
                        flash_surface = pygame.Surface((skill_size + 20, skill_size + 20), pygame.SRCALPHA)
                        pygame.draw.circle(
                            flash_surface,
                            (255, 255, 255, flash_alpha),
                            (flash_surface.get_width() // 2, flash_surface.get_height() // 2),
                            skill_size // 2 + 10,
                        )
                        self.screen.blit(flash_surface, (skill_x - 10, skill_y - 10))
                    for particle in anim_data["starburst"]:
                        if progress < 0.5:
                            movement_progress = 4 * progress * progress * progress
                        else:
                            p = 2 * progress - 2
                            movement_progress = 1 + p * p * p / 2
                        current_distance = particle["max_distance"] * movement_progress
                        px = center_x + math.cos(particle["angle"]) * current_distance
                        py = center_y + math.sin(particle["angle"]) * current_distance
                        twinkle = abs(math.sin(particle["sparkle_phase"] + elapsed * 0.01)) * 0.5 + 0.5
                        if progress < 0.85:
                            fade = 1.0
                        else:
                            fade = 1 - ((progress - 0.85) / 0.15)
                        brightness = int(particle["brightness"] * fade * twinkle)
                        if brightness > 0:
                            star_surface = pygame.Surface((12, 12), pygame.SRCALPHA)
                            star_center = 6
                            pygame.draw.line(star_surface, (255, 255, 200, brightness), (star_center, 2), (star_center, 10), 2)
                            pygame.draw.line(star_surface, (255, 255, 200, brightness), (2, star_center), (10, star_center), 2)
                            pygame.draw.line(star_surface, (255, 255, 230, brightness // 2), (3, 3), (9, 9), 1)
                            pygame.draw.line(star_surface, (255, 255, 230, brightness // 2), (9, 3), (3, 9), 1)
                            pygame.draw.circle(star_surface, (255, 255, 255, min(255, brightness + 50)), (star_center, star_center), int(particle["size"] / 2))
                            self.screen.blit(star_surface, (px - 6, py - 6))
                    for glitter in anim_data["glitter"]:
                        if elapsed > glitter["delay"]:
                            glitter["phase"] += glitter["speed"]
                            sparkle = (math.sin(glitter["phase"]) + 1) / 2
                            glitter_alpha = int(255 * sparkle)
                            glitter_surface = pygame.Surface((6, 6), pygame.SRCALPHA)
                            pygame.draw.circle(glitter_surface, (255, 255, 255, glitter_alpha), (3, 3), 2)
                            self.screen.blit(glitter_surface, (skill_x + skill_size // 2 + glitter["x"], skill_y + skill_size // 2 + glitter["y"]))
                    pulse = abs(math.sin(elapsed * 0.01)) * 0.5 + 0.5
                    glow_radius = int(skill_size // 2 + 15 * pulse)
                    glow_surf = pygame.Surface((glow_radius * 4, glow_radius * 4), pygame.SRCALPHA)
                    glow_alpha = int(60 * (1 - elapsed / anim_data["duration"]))
                    for j in range(3):
                        alpha = glow_alpha // (j + 1)
                        radius = glow_radius + j * 5
                        pygame.draw.circle(glow_surf, (255, 255, 100, alpha), (glow_radius * 2, glow_radius * 2), radius, 2)
                    self.screen.blit(glow_surf, (skill_x + skill_size // 2 - glow_radius * 2, skill_y + skill_size // 2 - glow_radius * 2))
                else:
                    del self.skill_levelup_animations[skill["id"]]

            name_text = self.font_small.render(skill["name"], True, (255, 255, 255))
            name_rect = name_text.get_rect(centerx=skill_x + skill_size // 2, top=skill_y + skill_size + 5)
            self.screen.blit(name_text, name_rect)

            gauge_width = skill_size + 20
            gauge_height = 10
            gauge_x = skill_x - 10
            gauge_y = name_rect.bottom + 5
            self.draw_skill_level_gauge(skill, gauge_x, gauge_y, gauge_width, gauge_height)

# Character expansion art & combat spec

The current game ships `frost` and `flame`. This design pack adds seven more IDs so the roster reaches nine.

## Shared sprite convention

```text
pixel art, 64x64 sprite per frame, side view facing right, clean pixel outlines, soft dithering shading, limited palette, crisp pixels, consistent proportions and colors across all frames, plain solid magenta background, game asset, sprite sheet in a single horizontal row
```

Runtime strips should be clean exports with transparent alpha. The magenta matte is only an authoring/keying aid.

Normal animation target:
- idle 6
- walk 8
- run 8 where used
- jump 4
- block/crouch_block 2–3
- attack1 5
- attack2 5
- attack3 6
- skill1 6
- skill2 6
- ult 10
- hurt 3
- ko 6
- win 6

## New roster

| id | name | palette | role |
| --- | --- | --- | --- |
| `umbrella` | Vũ Tán Tiên Tử | jade, pale pink, white, gold | counter / projectile reflect |
| `tang` | Đường Môn Ám Khí Sư | moss green, black, silver, poison purple | ranged / traps |
| `monk` | Đạo Tăng | saffron, gray, gold, cinnabar red | defense / control |
| `herder` | Mục Thần Đồng Tử | ivory, pale blue, gold, soft red | summon / pull |
| `elder` | Tàn Lão | earth brown, ash gray, silver | slow heavy melee |
| `demon` | Thiên Ma Nữ | deep purple, black, magenta, silver | speed / control |
| `beast` | Đại Khư Linh Thú | black, forest green, burnt orange, ivory | rushdown |

## Skill definitions

### umbrella
- Combo: 5 / 5 / 8.
- SK1 **Thanh Vũ Kiếm Châm**: 3 small-fan projectiles, 12 total, cost 25, cd 3s.
- SK2 **Hạ Vũ Phản Tán**: 0.6s counter; reflect projectile by swapping owner/direction; melee hit is cancelled and returns 15 damage, cost 35, cd 5s.
- ULT **Vạn Vũ Quy Tâm**: giant umbrella + arena rain multi-hit, 35 total.
- SK3 **Thu Tán Khinh Công**: glide + extra jump for 1.5s, heal 5 HP.
- Awakened ULT **Thiên Vũ Tán Hoa Khai**: reflect all projectiles for 3s, then 4 hits, 60 total.

### tang
- Combo: 5 / 5 / 8.
- SK1 **Lê Hoa Bạo Vũ**: 5 fan projectiles, 12 total.
- SK2 **Độc Chướng Địa Lôi**: trap 100px ahead; 15 damage + 0.5s stun; max one normal trap.
- ULT **Thiên La Địa Võng**: darken screen then weapons converge, 35 total.
- SK3 **Ám Khí Tàng Tiêu**: smoke vanish 1.5s, cannot be projectile-targeted, next attack +50%.
- Awakened ULT **Bạo Vũ Lê Hoa Tuyệt Mệnh**: 5 hits + poison, 60 total.

### monk
- Combo: 5 / 5 / 8.
- SK1 **Phù Chú Trấn Thế**: talisman projectile, 12 damage, 40% slow for 1.5s.
- SK2 **Kim Chung Hộ Thể**: invulnerable 1s then 15-damage knockback shockwave.
- ULT **Bát Quái Thiên Chưởng**: bagua + giant palm, 3 hits, 35 total.
- SK3 **Tâm Kinh Trấn Hồn**: meditate 2s, heal 10 HP + cleanse; interrupted by hit.
- Awakened ULT **Phật Quang Phổ Chiếu**: 4 hits, 60 total + self-heal 20.

### herder
- Combo: 5 / 5 / 8.
- SK1 **Thần Ảnh Chưởng**: giant palm hitbox 80px ahead, 12 damage.
- SK2 **Linh Tác Khiên Dẫn**: rope projectile, pull target 60px, stun 0.4s, 8 damage.
- ULT **Thần Ma Giáng Lâm**: giant phantom, three timed hits, 35 total.
- SK3 **Triệu Hồi Tiểu Thần Ảnh**: small phantom ally for 6s, attacks 3x5.
- Awakened ULT **Mục Thần Chi Thủ**: two giant phantoms clap from both sides, 4 hits, 60 total.

### elder
- Combo 6 / 6 / 10; slower movement and jump.
- SK1 **Chấn Địa Trượng**: grounded shockwave, 14 damage.
- SK2 **Thốn Kình Chưởng**: 20px step, fast palm, 15 damage + strong knockback.
- ULT **Vạn Văn Trấn Thế**: root target 1s then 3 explosions, 35 total.
- SK3 **Tàn Tâm Bất Diệt**: 3s, -50% incoming damage and no knockback.
- Awakened ULT **Nhất Chưởng Phá Thiên**: 1.5s uninterruptible charge, single unblockable 60 hit.

### demon
- Combo 4 / 4 / 7; faster walk and attack rate.
- SK1 **U Ảnh Xúc Tu**: 2 diagonal projectiles, 12 total.
- SK2 **Hóa Vụ Thân**: 0.2s invulnerable mist teleport behind target, slash for 14.
- ULT **Thiên Ma Giáng Thế**: shadow grab/swallow, 35 total.
- SK3 **Ma Ảnh Phân Thân**: clone for 4s mirroring attacks; first hit +50%.
- Awakened ULT **Thiên Ma Vạn Tượng**: black hole pulls target/projectiles, 5 hits, 60 total.

### beast
- Combo 5 / 5 / 8. Larger art may use 96x96 frames.
- SK1 **Liệt Trảo Khí**: orange claw wave, 12 damage.
- SK2 **Phi Hổ Phác**: 100px lunge through target, 15 damage.
- ULT **Đại Khư Thú Hống**: roar pushes to wall then 3 hits, 35 total.
- SK3 **Cuồng Huyết**: 4s +25% speed, +15% damage, 20% lifesteal.
- Awakened ULT **Khư Thú Chân Thân**: giant form for 10s, three 20-damage charges, 60 total.

## Awakening system reference

Separate awakening meter 0–100:
- +6 hit landed;
- +4 successful block;
- +3 when hit;
- stage kills: +5 normal / +20 elite / +50 boss;
- Linh Văn Thạch: +10;
- lower-HP fighter receives +50% awakening gain.

Tiers:
- Tier I >=30: unlock SK3 (cost 20 energy, cd 8s).
- Tier II >=60: enhanced SK1/SK2 (+20% damage plus extra effect).
- Tier III =100: 12s awakened state, +20% damage, energy regen x2, one awakened ULT per awakening.
- Maximum one awakening per round.

## Asset naming

- Character sprites: `SwordDuel/Resources/Assets/Characters/{id}/{id}_{anim}.png`
- VFX: `SwordDuel/Resources/Assets/VFX/{id}_*.png`
- Buttons: `SwordDuel/Resources/Assets/UI/btn_{id}_sk1.png`, `btn_{id}_sk2.png`, `btn_{id}_ult_locked.png`, `btn_{id}_ult_ready.png`, `btn_{id}_sk3.png`
- Beast / large phantom frame sizes should be data-driven rather than assumed 64x64.

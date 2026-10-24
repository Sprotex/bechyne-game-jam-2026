# Room authoring

Each room scene attaches `scripts/rooms/room.gd` and declares its `room_title`. The level reads that title for the HUD. Add a `Sprite2D` named `Background` and keep it at the artwork's native size. Set the room's `walkable_outline` points in background pixels; the room builds physical boundary segments along that outline. Use a distinct outline for each artwork rather than fitting every room to one shared rectangle. Add room-specific `StaticBody2D` furniture collisions where the art has solid furniture.

To add a door, instance `scenes/objects/room_exit.tscn`, set its wall side and position on the walkable outline, then set its destination scene path and destination arrival ID. The room cuts an opening from the nearest boundary segment. Add a `Marker2D` below `Arrivals` with that ID as its name, on the walkable side of the threshold. The reverse door is a separate exit in the destination room. Destination scene paths avoid cyclic `PackedScene` references while keeping room links directly editable in the Inspector.


The persistent player camera follows the player and uses each background texture's world rectangle as its limits. The CanvasLayer HUD stays anchored to the screen. The player position marks the feet; the sprite and collision shape sit above that point. Horizontal speed is 433 and the adjustable vertical speed ratio defaults to 0.55 for the high angle room art. Exit triggers sit at their threshold and arrival markers sit far enough inside the room to avoid immediately retriggering that exit.

## Persistent pickups and flags

Instance `scenes/persistent_pickup.tscn` for a collectible, give it a stable unique `item_id`, and set the displayed `item_label`. Interacting sets that ID in the level's flag store and hides the pickup. Other gameplay code can check `Level.has_flag("key.front_door")` to gate a door or dialog. Flags persist while the level is active, including across room changes, and reset when a new game session starts.

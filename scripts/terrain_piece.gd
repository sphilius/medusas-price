## terrain_piece.gd (base class for moving_platform.gd, crumbling_ledge.gd, column_platform.gd)
## Purpose: a small block of terrain that is NOT part of the level's Terrain layer, so
## it can move, crumble or be jumped through. It builds its own TileMapLayer of
## width_tiles x height_tiles cells from the shared terrain TileSet (so it collides like
## ground), then the level re-skins it with the same terrain shader as the ground
## (LevelBase.apply_terrain_look), so it looks like it was cut from the same stone.
## The node's position is the TOP-LEFT corner of the block.
class_name TerrainPiece
extends Node2D

const BASE_TILE_SET: TileSet = preload("res://art/tiles/terrain_tileset.tres")

## Size of the block in 32 px tiles.
@export var width_tiles: int = 3
@export var height_tiles: int = 1

## The block's tiles. Children of a piece add their own collision or art around it.
var tiles: TileMapLayer


## Builds the tiles before the level's _ready (children are ready before parents), and
## joins the group the level re-skins after it has built its own terrain look.
func _ready() -> void:
	tiles = TileMapLayer.new()
	tiles.name = "Tiles"
	tiles.tile_set = BASE_TILE_SET
	for x in width_tiles:
		for y in height_tiles:
			# set_cell(coords, source id, atlas coords): one 32 px tile per cell.
			tiles.set_cell(Vector2i(x, y), 0, Vector2i.ZERO)
	add_child(tiles)
	add_to_group(&"terrain_pieces")


## Size of the block in px.
func size_px() -> Vector2:
	return Vector2(width_tiles, height_tiles) * Balance.TILE_SIZE

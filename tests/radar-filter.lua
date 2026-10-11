package.path="./?.lua;"..package.path
local filter=require("system.navigation.radar_filter")
local kinds={player="players",mob="mobs",hostile="mobs",animal="mobs",sable="vessels",contraption="vessels",projectile="projectiles",missile="projectiles",item="other",entity="other"}
for category,expected in pairs(kinds) do assert(filter.category({category=category:upper()})==expected) end
assert(filter.category({category="entity",entityType="minecraft:player"})=="players")
local selected={}
assert(filter.visible({category="sable"},selected))
filter.toggle(selected,"players")
assert(filter.visible({category="player"},selected) and not filter.visible({category="sable"},selected))
filter.toggle(selected,"vessels") assert(filter.visible({category="sable"},selected))
filter.toggle(selected,"players") assert(not filter.visible({category="player"},selected))
filter.toggle(selected,"vessels") assert(filter.visible({category="player"},selected))
filter.toggle(selected,"mobs") filter.toggle(selected,"all") assert(next(selected)==nil)
assert(filter.select("abc","abc")==nil and filter.select("abc","def")=="def")
print("radar category filters and second-tap deselection passed")

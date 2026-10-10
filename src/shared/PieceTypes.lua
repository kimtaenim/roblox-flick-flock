-- 알 종류 이름 (숫자는 Config.Pieces 에)
local PieceTypes = {}

PieceTypes.DisplayName = {
	King = "왕알",
	Flat = "납작 알",
	Round = "둥근 알",
	Half = "0.5 알",
}

-- 팀 고르기에서 살 수 있는 알 (왕알은 기본 지급)
PieceTypes.Buyable = { "Flat", "Round", "Half" }

return PieceTypes

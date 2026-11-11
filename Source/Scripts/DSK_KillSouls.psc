Scriptname DSK_KillSouls extends Quest
{Души за убийства. Квест запускается через Story Manager (Kill Actor Event),
 поэтому после каждого события он сам себя останавливает.}

Actor Property PlayerRef Auto
MiscObject Property Gold001 Auto
Message Property DSK_SoulsGainedMsg Auto     ; "+%.0f душ" (можно пусто, чтобы не спамить)

Int Property MinSouls = 10 Auto
Float Property SoulsPerLevel = 6.0 Auto

Event OnStoryKillActor(ObjectReference akVictim, ObjectReference akKiller, Location akLocation, Int aiCrimeStatus, Int aiRelationshipRank)
	If akKiller == PlayerRef
		Actor victim = akVictim as Actor
		If victim
			Int souls = (MinSouls + victim.GetLevel() * SoulsPerLevel) as Int
			PlayerRef.AddItem(Gold001, souls, true)
			If DSK_SoulsGainedMsg
				DSK_SoulsGainedMsg.Show(souls)
			EndIf
		EndIf
	EndIf
	Stop()
EndEvent

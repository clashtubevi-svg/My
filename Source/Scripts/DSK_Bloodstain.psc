Scriptname DSK_Bloodstain extends ObjectReference
{Пятно крови на месте гибели. Скрипт на базовом Activator DSK_BloodstainBase.
 Активируй, чтобы вернуть души.}

DSK_Manager Property Manager Auto
Int Property StoredSouls = 0 Auto Hidden

Event OnActivate(ObjectReference akActionRef)
	If akActionRef == Game.GetPlayer()
		Manager.RecoverBloodstain(self)
	EndIf
EndEvent

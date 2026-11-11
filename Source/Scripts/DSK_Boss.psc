Scriptname DSK_Boss extends Actor
{Босс с фазами. Вешается на ссылку босса (или на его ActorBase).
 Фазы задаются массивами одинаковой длины: порог здоровья, способность, заклинание, сообщение.
 Пример: PhaseThresholds = [0.6, 0.3]. На 60% ХП включается фаза 1, на 30% фаза 2.}

DSK_BossFogGate Property Arena Auto Hidden     ; ставится туманом при начале боя

Float[] Property PhaseThresholds Auto          ; доля здоровья, по убыванию: 0.6, 0.3 ...
Spell[] Property PhaseAbilities Auto           ; постоянный бафф фазы (Ability), элементы могут быть пустыми
Spell[] Property PhaseCastSpells Auto          ; разовый каст при входе в фазу (взрыв, призыв), можно пусто
Message[] Property PhaseMessages Auto          ; "Страж разгорается яростью!", можно пусто

Int Property CurrentPhase = 0 Auto Hidden
Bool bChecking = false

Event OnHit(ObjectReference akAggressor, Form akSource, Projectile akProjectile, Bool abPowerAttack, Bool abSneakAttack, Bool abBashAttack, Bool abHitBlocked)
	CheckPhase()
EndEvent

Function CheckPhase()
	If bChecking || IsDead() || !PhaseThresholds
		Return
	EndIf
	bChecking = true
	Float hp = GetActorValuePercentage("Health")
	While CurrentPhase < PhaseThresholds.Length && hp <= PhaseThresholds[CurrentPhase]
		EnterPhase(CurrentPhase)
		CurrentPhase += 1
	EndWhile
	bChecking = false
EndFunction

Function EnterPhase(Int i)
	If PhaseAbilities && i < PhaseAbilities.Length && PhaseAbilities[i]
		AddSpell(PhaseAbilities[i], false)
	EndIf
	If PhaseCastSpells && i < PhaseCastSpells.Length && PhaseCastSpells[i]
		PhaseCastSpells[i].Cast(self, Game.GetPlayer())
	EndIf
	If PhaseMessages && i < PhaseMessages.Length && PhaseMessages[i]
		PhaseMessages[i].Show()
	EndIf
EndFunction

Function ResetBoss()
	; снять баффы фаз
	If PhaseAbilities
		Int i = 0
		While i < PhaseAbilities.Length
			If PhaseAbilities[i]
				RemoveSpell(PhaseAbilities[i])
			EndIf
			i += 1
		EndWhile
	EndIf
	CurrentPhase = 0
	If IsDead()
		Resurrect()
	EndIf
	StopCombat()
	RestoreActorValue("Health", 100000.0)
	RestoreActorValue("Magicka", 100000.0)
	RestoreActorValue("Stamina", 100000.0)
	MoveToMyEditorLocation()
	Disable()
EndFunction

Event OnDeath(Actor akKiller)
	If Arena
		Arena.OnBossDefeated()
	EndIf
EndEvent

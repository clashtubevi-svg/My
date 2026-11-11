Scriptname DSK_StaminaCombat extends ReferenceAlias
{Вешается на тот же алиас игрока. Каждый удар и каждый заблокированный удар тратят запас сил.
 На нуле запаса сил: изнеможение (слабые удары, медленнее движение), при блоке ещё и пробой защиты.}

GlobalVariable Property DSK_AttackStaminaCost Auto   ; цена удара (рекоменд. 15)
GlobalVariable Property DSK_BlockStaminaCost Auto    ; цена принятого в блок удара (рекоменд. 20)
Spell Property DSK_ExhaustedAbility Auto             ; Ability: AttackDamageMult -50%, SpeedMult -20
Spell Property DSK_GuardBreakSpell Auto              ; Spell с эффектом Stagger (пробой блока), можно пусто

Float Property ExhaustThreshold = 5.0 Auto
Float Property RecoverThreshold = 30.0 Auto
Float Property PollInterval = 0.3 Auto

Bool bExhausted = false

Event OnInit()
	RegisterAll()
EndEvent

Event OnPlayerLoadGame()
	; подписки на анимационные события после загрузки нужно обновлять
	RegisterAll()
EndEvent

Function RegisterAll()
	Actor p = GetActorReference()
	RegisterForAnimationEvent(p, "weaponSwing")
	RegisterForAnimationEvent(p, "weaponLeftSwing")
	RegisterForSingleUpdate(PollInterval)
EndFunction

Event OnAnimationEvent(ObjectReference akSource, String asEventName)
	If asEventName == "weaponSwing" || asEventName == "weaponLeftSwing"
		GetActorReference().DamageActorValue("Stamina", DSK_AttackStaminaCost.GetValue())
	EndIf
EndEvent

Event OnHit(ObjectReference akAggressor, Form akSource, Projectile akProjectile, Bool abPowerAttack, Bool abSneakAttack, Bool abBashAttack, Bool abHitBlocked)
	If !abHitBlocked
		Return
	EndIf
	Actor p = GetActorReference()
	Float cost = DSK_BlockStaminaCost.GetValue()
	If abPowerAttack
		cost = cost * 2.0
	EndIf
	p.DamageActorValue("Stamina", cost)
	If p.GetActorValue("Stamina") <= 0.0 && DSK_GuardBreakSpell && akAggressor
		DSK_GuardBreakSpell.Cast(akAggressor, p)
	EndIf
EndEvent

Event OnUpdate()
	Actor p = GetActorReference()
	Float st = p.GetActorValue("Stamina")
	If !bExhausted && st <= ExhaustThreshold
		bExhausted = true
		p.AddSpell(DSK_ExhaustedAbility, false)
	ElseIf bExhausted && st >= RecoverThreshold
		bExhausted = false
		p.RemoveSpell(DSK_ExhaustedAbility)
	EndIf
	RegisterForSingleUpdate(PollInterval)
EndEvent

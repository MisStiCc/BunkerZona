# managers/billing_manager.gd
extends Node
class_name BillingManager

## Биллинг Google Play (спека D16). Требует официальный плагин
## GodotGooglePlayBilling (AssetLib) + включение в Android-пресете.
## На ПК/в редакторе биллинга нет - store_available() = false.
## ВЕСЬ класс неактивен, пока StoreData.ENABLED == false.
##
## Поток: start() -> queryProducts -> витрина (цены стора; таблица
## StoreData.PRODUCTS - фолбэк для офлайн-UI). Покупка: purchase ->
## токен -> acknowledge (требование Google: 3 дня) -> начисление payload
## -> сейв. Восстановление: queryPurchases (nc - всегда; расходники
## после расходования - нет, честная плашка в UI).

signal products_loaded(prices: Dictionary)     # sku -> локализованная цена
signal purchase_granted(sku: String)
signal purchase_failed(reason: String)

const PLUGIN_SINGLETON := "GodotGooglePlayBilling"

var _billing = null                            # Engine singleton плагина
var _connected: bool = false


func _ready() -> void:
	add_to_group("billing")


## Доступен ли магазин вообще (флаг + платформа + плагин)
func store_available() -> bool:
	if not StoreData.ENABLED:
		return false
	if not OS.has_feature("android"):
		return false
	return Engine.has_singleton(PLUGIN_SINGLETON)


## Подключение к стору. Безопасно звать всегда: без флага - тихий выход.
func start() -> void:
	if not store_available():
		return
	_billing = Engine.get_singleton(PLUGIN_SINGLETON)
	if _billing.has_signal("connected"):
		_billing.connect("connected", _on_connected)
	if _billing.has_signal("products_loaded"):
		_billing.connect("products_loaded", _on_products_loaded)
	if _billing.has_signal("purchases_updated"):
		_billing.connect("purchases_updated", _on_purchases_updated)
	if _billing.has_signal("purchase_error"):
		_billing.connect("purchase_error", _on_purchase_error)
	_billing.startConnection()


func query_products() -> void:
	if _connected and _billing:
		_billing.queryProducts(StoreData.PRODUCTS.keys())


func purchase(sku: String) -> void:
	if not store_available():
		purchase_failed.emit("store_unavailable")
		return
	if not StoreData.PRODUCTS.has(sku):
		purchase_failed.emit("unknown_sku")
		return
	_billing.purchaseProduct(sku)


## Восстановление nc-покупок (пропуск/косметика/удобства)
func restore() -> void:
	if _connected and _billing:
		_billing.queryPurchases()


func _on_connected(_result) -> void:
	_connected = true
	query_products()


func _on_products_loaded(products) -> void:
	# products: массив {id, price} - отдаём витрине
	var prices: Dictionary = {}
	for p in products:
		prices[str(p.get("id", ""))] = str(p.get("price", ""))
	products_loaded.emit(prices)


func _on_purchases_updated(purchases) -> void:
	# Каждую покупку: acknowledge + начисление (через zone/game_manager снаружи)
	for p in purchases:
		var sku: String = str(p.get("sku", ""))
		var token: String = str(p.get("purchase_token", ""))
		if sku == "" or token == "":
			continue
		if _billing and _billing.has_method("acknowledgePurchase"):
			_billing.acknowledgePurchase(token)
		purchase_granted.emit(sku)


func _on_purchase_error(_code, _msg) -> void:
	purchase_failed.emit("purchase_error")

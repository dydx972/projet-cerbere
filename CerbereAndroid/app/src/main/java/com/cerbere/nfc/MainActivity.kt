package com.cerbere.nfc

import android.app.PendingIntent
import android.content.Intent
import android.content.IntentFilter
import android.content.SharedPreferences
import android.nfc.NfcAdapter
import android.nfc.Tag
import android.os.Bundle
import android.os.VibrationEffect
import android.os.Vibrator
import android.view.LayoutInflater
import android.view.View
import android.widget.*
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import kotlinx.coroutines.*
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.util.concurrent.TimeUnit

class MainActivity : AppCompatActivity() {

    private var nfcAdapter: NfcAdapter? = null
    private lateinit var prefs: SharedPreferences
    private lateinit var client: OkHttpClient
    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())

    // UI
    private lateinit var statusIcon: TextView
    private lateinit var statusText: TextView
    private lateinit var statusDetail: TextView
    private lateinit var lastBadgeText: TextView
    private lateinit var badgeList: LinearLayout
    private lateinit var badgeCountText: TextView
    private lateinit var modeSwitch: Switch
    private lateinit var statusCard: LinearLayout

    // State
    private var isRegisterMode = false
    private var badges: MutableMap<String, String> = mutableMapOf() // UID -> nom

    companion object {
        private const val PREFS_NAME = "cerbere_nfc"
        private const val KEY_BADGES = "badges"
        private const val DOOR_API = "http://192.168.1.49:5000/ouvrir"
        private const val SECRET = "cerbere2026"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
        client = OkHttpClient.Builder()
            .connectTimeout(5, TimeUnit.SECONDS)
            .readTimeout(5, TimeUnit.SECONDS)
            .build()

        // Bind views
        statusIcon = findViewById(R.id.statusIcon)
        statusText = findViewById(R.id.statusText)
        statusDetail = findViewById(R.id.statusDetail)
        lastBadgeText = findViewById(R.id.lastBadgeText)
        badgeList = findViewById(R.id.badgeList)
        badgeCountText = findViewById(R.id.badgeCountText)
        modeSwitch = findViewById(R.id.modeSwitch)
        statusCard = findViewById(R.id.statusCard)

        modeSwitch.setOnCheckedChangeListener { _, checked ->
            isRegisterMode = checked
            if (checked) {
                setStatus("register", "MODE ENREGISTREMENT", "Passez un badge pour l'enregistrer")
            } else {
                setStatus("ready", "PRET", "En attente d'un badge...")
            }
        }

        loadBadges()
        refreshBadgeList()

        nfcAdapter = NfcAdapter.getDefaultAdapter(this)
        if (nfcAdapter == null) {
            setStatus("error", "NFC INDISPONIBLE", "Ce telephone ne supporte pas le NFC")
            return
        }
        if (!nfcAdapter!!.isEnabled) {
            setStatus("error", "NFC DESACTIVE", "Activez le NFC dans les parametres")
            return
        }

        setStatus("ready", "PRET", "En attente d'un badge...")
        handleIntent(intent)
    }

    override fun onResume() {
        super.onResume()
        nfcAdapter?.let { adapter ->
            val pendingIntent = PendingIntent.getActivity(
                this, 0,
                Intent(this, javaClass).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
                PendingIntent.FLAG_MUTABLE
            )
            val filters = arrayOf(
                IntentFilter(NfcAdapter.ACTION_TAG_DISCOVERED),
                IntentFilter(NfcAdapter.ACTION_TECH_DISCOVERED)
            )
            adapter.enableForegroundDispatch(this, pendingIntent, filters, null)
        }
    }

    override fun onPause() {
        super.onPause()
        nfcAdapter?.disableForegroundDispatch(this)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent) {
        val tag: Tag? = intent.getParcelableExtra(NfcAdapter.EXTRA_TAG)
        tag?.let { processTag(it) }
    }

    private fun processTag(tag: Tag) {
        val uid = tag.id.joinToString(":") { "%02X".format(it) }
        vibrate()
        lastBadgeText.text = uid

        if (isRegisterMode) {
            showRegisterDialog(uid)
        } else {
            checkAndOpen(uid)
        }
    }

    private fun checkAndOpen(uid: String) {
        if (badges.containsKey(uid)) {
            val name = badges[uid] ?: uid
            setStatus("granted", "ACCES AUTORISE", "$name ($uid)")
            openDoor()
        } else {
            setStatus("denied", "ACCES REFUSE", "Badge inconnu : $uid")
            scope.launch {
                delay(3000)
                if (!isRegisterMode) setStatus("ready", "PRET", "En attente d'un badge...")
            }
        }
    }

    private fun openDoor() {
        scope.launch {
            try {
                withContext(Dispatchers.IO) {
                    val json = """{"secret":"$SECRET","duree":5}"""
                    val body = json.toRequestBody("application/json".toMediaType())
                    val request = Request.Builder().url(DOOR_API).post(body).build()
                    client.newCall(request).execute().use { response ->
                        withContext(Dispatchers.Main) {
                            if (response.isSuccessful) {
                                statusDetail.text = statusDetail.text.toString() + "\nPorte ouverte 5s"
                            } else {
                                statusDetail.text = statusDetail.text.toString() + "\nErreur serveur: ${response.code}"
                            }
                        }
                    }
                }
            } catch (e: Exception) {
                statusDetail.text = statusDetail.text.toString() + "\nErreur: ${e.message}"
            }
            delay(5000)
            if (!isRegisterMode) setStatus("ready", "PRET", "En attente d'un badge...")
        }
    }

    private fun showRegisterDialog(uid: String) {
        if (badges.containsKey(uid)) {
            setStatus("granted", "BADGE DEJA ENREGISTRE", "${badges[uid]} ($uid)")
            scope.launch {
                delay(2000)
                setStatus("register", "MODE ENREGISTREMENT", "Passez un badge pour l'enregistrer")
            }
            return
        }

        val input = EditText(this).apply {
            hint = "Nom du badge (ex: Dylan, Visiteur...)"
            setPadding(48, 32, 48, 32)
        }

        AlertDialog.Builder(this, R.style.DialogTheme)
            .setTitle("Enregistrer le badge")
            .setMessage("UID : $uid")
            .setView(input)
            .setPositiveButton("Enregistrer") { _, _ ->
                val name = input.text.toString().ifBlank { "Badge ${badges.size + 1}" }
                badges[uid] = name
                saveBadges()
                refreshBadgeList()
                setStatus("granted", "BADGE ENREGISTRE", "$name ($uid)")
                scope.launch {
                    delay(2000)
                    setStatus("register", "MODE ENREGISTREMENT", "Passez un badge pour l'enregistrer")
                }
            }
            .setNegativeButton("Annuler", null)
            .show()
    }

    private fun setStatus(type: String, title: String, detail: String) {
        statusText.text = title
        statusDetail.text = detail
        when (type) {
            "ready" -> {
                statusIcon.text = "\uD83D\uDFE2" // green circle
                statusCard.setBackgroundResource(R.drawable.card_bg_dark)
            }
            "register" -> {
                statusIcon.text = "\uD83D\uDFE1" // yellow circle
                statusCard.setBackgroundResource(R.drawable.card_bg_yellow)
            }
            "granted" -> {
                statusIcon.text = "\u2705" // check
                statusCard.setBackgroundResource(R.drawable.card_bg_green)
            }
            "denied" -> {
                statusIcon.text = "\u274C" // cross
                statusCard.setBackgroundResource(R.drawable.card_bg_red)
            }
            "error" -> {
                statusIcon.text = "\u26A0\uFE0F" // warning
                statusCard.setBackgroundResource(R.drawable.card_bg_red)
            }
        }
    }

    private fun refreshBadgeList() {
        badgeList.removeAllViews()
        badgeCountText.text = "${badges.size} badge(s) enregistre(s)"

        for ((uid, name) in badges) {
            val row = LayoutInflater.from(this).inflate(R.layout.badge_row, badgeList, false)
            row.findViewById<TextView>(R.id.badgeName).text = name
            row.findViewById<TextView>(R.id.badgeUid).text = uid
            row.findViewById<ImageButton>(R.id.deleteBtn).setOnClickListener {
                AlertDialog.Builder(this, R.style.DialogTheme)
                    .setTitle("Supprimer $name ?")
                    .setMessage("UID : $uid")
                    .setPositiveButton("Supprimer") { _, _ ->
                        badges.remove(uid)
                        saveBadges()
                        refreshBadgeList()
                    }
                    .setNegativeButton("Annuler", null)
                    .show()
            }
            badgeList.addView(row)
        }
    }

    private fun saveBadges() {
        prefs.edit().putString(KEY_BADGES, Gson().toJson(badges)).apply()
    }

    private fun loadBadges() {
        val json = prefs.getString(KEY_BADGES, null) ?: return
        val type = object : TypeToken<MutableMap<String, String>>() {}.type
        badges = Gson().fromJson(json, type)
    }

    private fun vibrate() {
        val vibrator = getSystemService(VIBRATOR_SERVICE) as? Vibrator ?: return
        vibrator.vibrate(VibrationEffect.createOneShot(100, VibrationEffect.DEFAULT_AMPLITUDE))
    }

    override fun onDestroy() {
        super.onDestroy()
        scope.cancel()
    }
}

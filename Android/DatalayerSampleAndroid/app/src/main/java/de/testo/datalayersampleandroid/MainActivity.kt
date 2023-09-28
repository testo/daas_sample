package de.testo.datalayersampleandroid


import android.app.Activity
import android.content.pm.PackageManager
import android.os.Bundle
import android.util.Log
import android.widget.Button
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.core.app.ActivityCompat
import de.testo.datalayer.loadLibrary
import de.testo.datalayer.probes.*
import kotlinx.coroutines.ExperimentalCoroutinesApi
import java.text.SimpleDateFormat
import java.util.*
import kotlin.concurrent.thread

const val TAG = "datalayer_sample_app"


class MainActivity : AppCompatActivity() {

    companion object {
        init {
            loadLibrary()
        }
    }

    private var text: TextView? = null
    private var textMultiLine: TextView? = null
    private var buttonDiscover: Button? = null
    private var buttonConnect: Button? = null
    private var buttonDisconnect: Button? = null
    private var buttonBattery: Button? = null
    private var buttonAvailable: Button? = null

    private val PERMISSION_REQUEST_CODE = 1

    private val formatter = "HH:mm:ss:S"

    private var probeFactory: ProbeFactory? = null
    private val probes: MutableMap<String, Probe> = mutableMapOf()

    @ExperimentalCoroutinesApi
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        text = findViewById(R.id.textview)
        textMultiLine = findViewById(R.id.textMultiLine)
        buttonDiscover = findViewById(R.id.buttondiscover)
        buttonConnect = findViewById(R.id.buttonconnect)
        buttonDisconnect = findViewById(R.id.buttondisconnect)
        buttonBattery = findViewById(R.id.buttonbattery)
        buttonAvailable = findViewById(R.id.buttonavailable)
        probeFactory = ProbeFactory(application)

        requestPermissionsForBluetooth(this)

        probeFactory?.startBtScan()

        buttonDiscover?.setOnClickListener {
            onDiscoverClicked()
        }

        buttonConnect?.setOnClickListener {
            onConnectClicked()
        }
        buttonDisconnect?.setOnClickListener {
            onDisconnectClicked()
        }
        buttonBattery?.setOnClickListener {
            onBatteryClicked()
        }
        buttonAvailable?.setOnClickListener {
            onDeviceAvailableClicked()
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int, permissions: Array<String>, grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        when (requestCode) {
            PERMISSION_REQUEST_CODE -> {
                if ((grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED)) {
                    probeFactory?.startBtScan()
                }
                return
            }
        }
    }

    private fun fromKelvinToCelsius(value: Float): Float {
        return value - 273.15f
    }

    private fun generateNotifyString(
        type: String, uuid: String, measType: String, length: Int, value: Float
    ): String {
        return "<$type $uuid $measType: " + "%.${length}f >".format(fromKelvinToCelsius(value))
    }

    private fun generateCreateString(
        type: String, uuid: String, batteryLevel: Float): String {
        return "<create $type $uuid ${"Battery level: %.0f ".format(batteryLevel)}%>"
    }

    private fun printString(str: String) {
        if (str.isNotEmpty()) {
            this.runOnUiThread {
                val dateTime = SimpleDateFormat(
                    formatter,
                    Locale.getDefault()
                ).format(Calendar.getInstance().time)
                val text = "$dateTime : $str \n${textMultiLine?.text.toString()}"
                textMultiLine?.text = text
            }
            Log.i(TAG, str)
        }
    }

    private fun onDiscoverClicked() {
        printString("Discovered devices:${probeFactory?.getConnectableDevices()?.map { "${it.serialNo} ${it.probeType} " }}")
    }

    @ExperimentalCoroutinesApi
    private fun onConnectClicked() {
        val devices = probeFactory?.getConnectableDevices()
        if (devices != null) {
            printString("Connection to devices:${devices.map { "${it.serialNo} ${it.probeType} " }}")
            for (device in devices) {
                thread(start = true) {
                    val probe = probeFactory!!.create(device)
                    probes[device.serialNo] = probe
                    when (device.probeType) {
                        ProbeType.T104_IR_BT -> {
                            val notifyMeasValueFunc: NotifyFunction = {
                                if (it != null) {
                                    printString(
                                        generateNotifyString(
                                            ProbeType.T104_IR_BT.value,
                                            device.serialNo + "," + device.probeType,
                                            it.measType?.name ?: "",
                                            it.physicalUnit?.length ?: 1,
                                            it.probeValue?.value!!
                                        )
                                    )
                                }
                            }
                            probe.subscribeNotification(
                                MeasType.SURFACE_TEMPERATURE,
                                notifyMeasValueFunc
                            )
                            probe.subscribeNotification(
                                MeasType.PLUNGE_TEMPERATURE,
                                notifyMeasValueFunc
                            )
                            printString(
                                generateCreateString(
                                    ProbeType.T104_IR_BT.value,
                                    device.serialNo + "," + device.probeType,
                                    probe.getBatteryLevel()
                                )
                            )
                        }

                        ProbeType.MF_HANDLE -> {
                            val notifyMeasValueFunc: NotifyFunction = {
                                if (it != null) {
                                    printString(
                                        generateNotifyString(
                                            ProbeType.MF_HANDLE.value,
                                            device.serialNo + "," + device.probeType,
                                            it.measType?.name ?: "",
                                            it.physicalUnit?.length ?: 1,
                                            it.probeValue?.value!!
                                        )
                                    )
                                }
                            }
                            probe.subscribeNotification(
                                MeasType.TEMPERATURE, notifyMeasValueFunc
                            )
                            printString(
                                generateCreateString(
                                    ProbeType.MF_HANDLE.value,
                                    device.serialNo + "," + device.probeType,
                                    probe.getBatteryLevel()
                                )
                            )
                        }

                        ProbeType.QSR_HANDLE -> {
                            val notifyMeasValueFunc: NotifyFunction = {
                                if (it != null) {
                                    printString(
                                        generateNotifyString(
                                            ProbeType.QSR_HANDLE.value,
                                            device.serialNo + "," + device.probeType,
                                            it.measType?.name ?: "",
                                            it.physicalUnit?.length ?: 1,
                                            it.probeValue?.value!!
                                        )
                                    )
                                }
                            }
                            probe.subscribeNotification(
                                MeasType.TEMPERATURE, notifyMeasValueFunc
                            )
                            printString(
                                generateCreateString(
                                    ProbeType.QSR_HANDLE.value,
                                    device.serialNo + "," + device.probeType,
                                    probe.getBatteryLevel()
                                )
                            )
                        }

                        else -> printString("unhandled probe type")
                    }
                }
            }
        }
    }

    @ExperimentalCoroutinesApi
    private fun onDisconnectClicked() {
        if (probeFactory != null) {
            val devicesDisconnect: MutableList<String> = emptyList<String>().toMutableList()
            thread(start = true) {
                for (device in probes) {
                    devicesDisconnect += device.value.getDeviceId()
                    device.value.disconnect()
                }
                probes.clear()
                if(devicesDisconnect.isNotEmpty()){
                    printString(
                        "Devices ${
                            devicesDisconnect.toString().removeSurrounding("[", "]")
                        } disconnected!"
                    )
                }
            }
        }
    }

    private fun onBatteryClicked() {
        if (probeFactory != null) {
            thread(start = true) {
                for (device in probes) {
                    printString("<device ${device.value.getDeviceId()} ${device.key} battery: ${device.value.getBatteryLevel()}>")
                }
            }
        }
    }

    private fun onDeviceAvailableClicked() {
        if (probeFactory != null) {
            for (device in probes) {
                printString(
                    "<device ${device.value.getDeviceId()} ${device.key} available ${
                        device.value.isDeviceAvailable()
                    }>"
                )
            }
        }
    }

    private fun requestPermissionsForBluetooth(
        requestingActivity: Activity?
    ) {
        if (requestingActivity != null) {
            probeFactory?.let {
                ActivityCompat.requestPermissions(
                    requestingActivity, it.requiredPermissions, PERMISSION_REQUEST_CODE
                )
            }
        }
    }
}
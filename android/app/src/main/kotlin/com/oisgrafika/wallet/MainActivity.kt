package com.oisgrafika.wallet

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import android.view.WindowManager
import android.os.Bundle
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import java.io.ByteArrayOutputStream
import java.io.File
import android.os.ParcelFileDescriptor
import android.graphics.pdf.PdfRenderer
import android.graphics.Bitmap
import android.provider.MediaStore
import android.os.Build
import android.content.ContentValues
import android.app.Activity
import android.net.Uri
import android.provider.DocumentsContract

class MainActivity: FlutterFragmentActivity() 
  {
    private val CHANNEL = "com.oisgrafika.wallet/save_file"
    private var pendingBytes: ByteArray? = null
    private var pendingResult: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: Bundle?) {
      super.onCreate(savedInstanceState)
      window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) 
      {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
          when (call.method) {
            "savePkpass" -> {
              val bytes = call.argument<ByteArray>("bytes")
              val name = call.argument<String>("name")
              if (bytes != null && name != null) {
                pendingBytes = bytes
                pendingResult = result
                val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                  addCategory(Intent.CATEGORY_OPENABLE)
                  type = "application/vnd.apple.pkpass"
                  putExtra(Intent.EXTRA_TITLE, name)
                }
                startActivityForResult(intent, 1001)
              } else {
                result.error("INVALID_ARGUMENTS", "Bytes or name is null", null)
              }
            }
            "pickDirectory" -> {
              pendingResult = result
              val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE)
              startActivityForResult(intent, 1002)
            }
            "writeToUri" -> {
              val uriString = call.argument<String>("uri")
              val bytes = call.argument<ByteArray>("bytes")
              val filename = call.argument<String>("filename")
              if (uriString != null && bytes != null && filename != null) {
                try {
                  val treeUri = Uri.parse(uriString)
                  val docUri = buildChildUri(treeUri, filename)
                  val targetUri = if (documentExists(docUri)) {
                    docUri
                  } else {
                    val treeDocumentId = DocumentsContract.getTreeDocumentId(treeUri)
                    val parentDocumentUri = DocumentsContract.buildDocumentUriUsingTree(treeUri, treeDocumentId)
                    DocumentsContract.createDocument(
                      contentResolver,
                      parentDocumentUri,
                      "application/octet-stream",
                      filename
                    ) ?: throw Exception("Failed to create document")
                  }
                  contentResolver.openOutputStream(targetUri, "w")?.use { it.write(bytes) }
                  result.success(true)
                } catch (e: Exception) {
                  result.error("WRITE_FAILED", e.message, null)
                }
              } else {
                result.error("INVALID_ARGUMENTS", "Missing uri, bytes, or filename", null)
              }
            }
            "readFromUri" -> {
              val uriString = call.argument<String>("uri")
              val filename = call.argument<String>("filename")
              if (uriString != null && filename != null) {
                try {
                  val treeUri = Uri.parse(uriString)
                  val docUri = buildChildUri(treeUri, filename)
                  val bytes = contentResolver.openInputStream(docUri)?.use { it.readBytes() }
                  if (bytes != null) {
                    result.success(bytes)
                  } else {
                    result.error("READ_FAILED", "Could not read file", null)
                  }
                } catch (e: Exception) {
                  result.error("READ_FAILED", e.message, null)
                }
              } else {
                result.error("INVALID_ARGUMENTS", "Missing uri or filename", null)
              }
            }
            "deleteFromUri" -> {
              val uriString = call.argument<String>("uri")
              val filename = call.argument<String>("filename")
              if (uriString != null && filename != null) {
                try {
                  val treeUri = Uri.parse(uriString)
                  val docUri = buildChildUri(treeUri, filename)
                  contentResolver.delete(docUri, null, null)
                  result.success(true)
                } catch (e: Exception) {
                  result.success(false)
                }
              } else {
                result.error("INVALID_ARGUMENTS", "Missing uri or filename", null)
              }
            }
            "renderPdfFirstPage" -> {
              val bytes = call.argument<ByteArray>("bytes")
              if (bytes == null) {
                result.error("INVALID_ARGUMENTS", "Missing PDF bytes", null)
              } else {
                var tempFile: File? = null
                var descriptor: ParcelFileDescriptor? = null
                var renderer: PdfRenderer? = null
                try {
                  tempFile = File(cacheDir, "ois_preview_${System.nanoTime()}.pdf")
                  tempFile.writeBytes(bytes)
                  descriptor = ParcelFileDescriptor.open(tempFile, ParcelFileDescriptor.MODE_READ_ONLY)
                  renderer = PdfRenderer(descriptor)
                  if (renderer.pageCount <= 0) throw Exception("PDF has no pages")
                  val page = renderer.openPage(0)
                  val targetWidth = 1200
                  val targetHeight = ((page.height.toDouble() / page.width.toDouble()) * targetWidth).toInt().coerceAtLeast(1)
                  val bitmap = Bitmap.createBitmap(targetWidth, targetHeight, Bitmap.Config.ARGB_8888)
                  bitmap.eraseColor(android.graphics.Color.WHITE)
                  page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                  page.close()
                  val output = ByteArrayOutputStream()
                  bitmap.compress(Bitmap.CompressFormat.PNG, 92, output)
                  bitmap.recycle()
                  result.success(output.toByteArray())
                } catch (e: Exception) {
                  result.error("PDF_RENDER_FAILED", e.message, null)
                } finally {
                  try { renderer?.close() } catch (_: Exception) {}
                  try { descriptor?.close() } catch (_: Exception) {}
                  try { tempFile?.delete() } catch (_: Exception) {}
                }
              }
            }
            "saveImageToGallery" -> {
              val bytes = call.argument<ByteArray>("bytes")
              val name = call.argument<String>("name")
              if (bytes == null || name == null) {
                result.error("INVALID_ARGUMENTS", "Missing bytes or name", null)
              } else {
                try {
                  val values = ContentValues().apply {
                    put(MediaStore.Images.Media.DISPLAY_NAME, name)
                    put(MediaStore.Images.Media.MIME_TYPE, "image/png")
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                      put(MediaStore.Images.Media.RELATIVE_PATH, "Pictures/OIS Wallet")
                      put(MediaStore.Images.Media.IS_PENDING, 1)
                    }
                  }
                  val collection = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
                  } else {
                    MediaStore.Images.Media.EXTERNAL_CONTENT_URI
                  }
                  val uri = contentResolver.insert(collection, values)
                    ?: throw Exception("Unable to create gallery item")
                  contentResolver.openOutputStream(uri)?.use { it.write(bytes) }
                    ?: throw Exception("Unable to open gallery output stream")
                  if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    val done = ContentValues().apply { put(MediaStore.Images.Media.IS_PENDING, 0) }
                    contentResolver.update(uri, done, null, null)
                  }
                  result.success(uri.toString())
                } catch (e: Exception) {
                  result.error("GALLERY_SAVE_FAILED", e.message, null)
                }
              }
            }
            "shareMediaUri" -> {
              val uriString = call.argument<String>("uri")
              val mimeType = call.argument<String>("mimeType") ?: "image/png"
              if (uriString == null) {
                result.error("INVALID_ARGUMENTS", "Missing uri", null)
              } else {
                try {
                  val sendIntent = Intent(Intent.ACTION_SEND).apply {
                    type = mimeType
                    putExtra(Intent.EXTRA_STREAM, Uri.parse(uriString))
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                  }
                  startActivity(Intent.createChooser(sendIntent, "Share from OIS Finance"))
                  result.success(true)
                } catch (e: Exception) {
                  result.error("SHARE_FAILED", e.message, null)
                }
              }
            }
            else -> result.notImplemented()
          }
        }
        FinanceNativeBridge.setup(this, flutterEngine)
      }

    override fun onNewIntent(intent: Intent) {
      super.onNewIntent(intent)
      setIntent(intent)
    }

    private fun buildChildUri(treeUri: Uri, filename: String): Uri {
      val treeDocumentId = DocumentsContract.getTreeDocumentId(treeUri)
      val childDocumentId = "$treeDocumentId/$filename"
      return DocumentsContract.buildDocumentUriUsingTree(treeUri, childDocumentId)
    }

    private fun documentExists(uri: Uri): Boolean {
      return try {
        contentResolver.query(uri, arrayOf(DocumentsContract.Document.COLUMN_DOCUMENT_ID), null, null, null)?.use { cursor ->
          cursor.count > 0
        } ?: false
      } catch (e: Exception) {
        false
      }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
      super.onActivityResult(requestCode, resultCode, data)
      when (requestCode) {
        1001 -> {
          if (resultCode == Activity.RESULT_OK && data != null) {
            val uri = data.data
            if (uri != null) {
              try {
                val bytes = pendingBytes
                if (bytes == null) {
                  pendingResult?.error("SAVE_FAILED", "No pending file data", null)
                } else {
                  contentResolver.openOutputStream(uri)?.use { outputStream ->
                    outputStream.write(bytes)
                  } ?: throw Exception("Unable to open output stream")
                  pendingResult?.success(uri.toString())
                }
              } catch (e: Exception) {
                pendingResult?.error("SAVE_FAILED", e.message, null)
              }
            } else {
              pendingResult?.error("URI_NULL", "Received null URI", null)
            }
          } else {
            pendingResult?.success(null)
          }
          pendingBytes = null
          pendingResult = null
        }
        1002 -> {
          if (resultCode == Activity.RESULT_OK && data != null) {
            val uri = data.data
            if (uri != null) {
              try {
                contentResolver.takePersistableUriPermission(
                  uri,
                  Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                )
                pendingResult?.success(uri.toString())
              } catch (e: Exception) {
                pendingResult?.error("PERMISSION_FAILED", e.message, null)
              }
            } else {
              pendingResult?.error("URI_NULL", "Received null URI", null)
            }
          } else {
            pendingResult?.success(null)
          }
          pendingResult = null
        }
      }
    }
  }

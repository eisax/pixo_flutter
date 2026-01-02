//! C-ABI FFI bindings for pixo.
//!
//! This module exposes a small, stable surface for use from other languages
//! (e.g., Dart via `dart:ffi`). It intentionally mirrors the high-level
//! presets used in the WASM bindings to keep the API compact.

use std::ffi::CString;
use std::os::raw::c_char;
use std::panic::{catch_unwind, AssertUnwindSafe};

use crate::color::ColorType;
use crate::jpeg::{self, JpegOptions, Subsampling};
use crate::png::{self, PngOptions};

/// Status code returned from FFI calls.
#[repr(C)]
pub enum PixoStatus {
    Ok = 0,
    InvalidArg = 1,
    EncodeError = 2,
    Panic = 3,
}

fn color_type_from_u8_png(value: u8) -> Result<ColorType, String> {
    ColorType::try_from(value).map_err(|v| {
        format!(
            "Invalid color type for PNG: {v}. Expected 0 (Gray), 1 (GrayAlpha), 2 (Rgb), or 3 (Rgba)",
        )
    })
}

fn color_type_from_u8_jpeg(value: u8) -> Result<ColorType, String> {
    match ColorType::try_from(value) {
        Ok(ColorType::Gray) => Ok(ColorType::Gray),
        Ok(ColorType::Rgb) => Ok(ColorType::Rgb),
        _ => Err(format!(
            "Invalid color type for JPEG: {value}. Expected 0 (Gray) or 2 (Rgb)",
        )),
    }
}

fn set_error(err_msg: *mut *mut c_char, msg: String) {
    if err_msg.is_null() {
        return;
    }
    // Best-effort: if CString::new fails due to embedded NUL, fall back to a
    // generic message.
    let c_string = CString::new(msg).unwrap_or_else(|_| CString::new("pixo error").unwrap());
    unsafe {
        *err_msg = c_string.into_raw();
    }
}

fn clear_error(err_msg: *mut *mut c_char) {
    if err_msg.is_null() {
        return;
    }
    unsafe {
        *err_msg = std::ptr::null_mut();
    }
}

/// Encode raw pixel data as PNG.
///
/// # Safety
/// - `data_ptr` must point to a valid buffer of `data_len` bytes.
/// - `out_ptr` and `out_len` must be valid, non-null pointers where the
///   resulting buffer pointer and length will be written on success.
/// - The caller is responsible for eventually calling `pixo_free_buffer` on
///   the returned buffer.
#[no_mangle]
pub extern "C" fn pixo_encode_png_pixels(
    data_ptr: *const u8,
    data_len: usize,
    width: u32,
    height: u32,
    color_type: u8,
    preset: u8,
    lossless: bool,
    out_ptr: *mut *mut u8,
    out_len: *mut usize,
    err_msg: *mut *mut c_char,
) -> PixoStatus {
    clear_error(err_msg);

    if data_ptr.is_null() || out_ptr.is_null() || out_len.is_null() {
        set_error(err_msg, "null pointer argument".to_string());
        return PixoStatus::InvalidArg;
    }

    let result = catch_unwind(AssertUnwindSafe(|| {
        let color = color_type_from_u8_png(color_type)?;

        // Preserve explicit color type from caller.
        let mut builder = PngOptions::builder(width, height).color_type(color).preset(preset);
        if !lossless {
            builder = builder.lossy(true);
        }
        let options = builder.build();

        let data = unsafe { std::slice::from_raw_parts(data_ptr, data_len) };
        match png::encode(data, &options) {
            Ok(mut encoded) => {
                // Leak Vec to FFI caller.
                let ptr = encoded.as_mut_ptr();
                let len = encoded.len();
                std::mem::forget(encoded);
                unsafe {
                    *out_ptr = ptr;
                    *out_len = len;
                }
                Ok(())
            }
            Err(e) => Err(e.to_string()),
        }
    }));

    match result {
        Ok(Ok(())) => PixoStatus::Ok,
        Ok(Err(msg)) => {
            set_error(err_msg, msg);
            PixoStatus::EncodeError
        }
        Err(_) => {
            set_error(err_msg, "panic during PNG encode".to_string());
            PixoStatus::Panic
        }
    }
}

/// Encode raw pixel data as JPEG.
///
/// See `pixo_encode_png_pixels` for safety and ownership rules.
#[no_mangle]
pub extern "C" fn pixo_encode_jpeg_pixels(
    data_ptr: *const u8,
    data_len: usize,
    width: u32,
    height: u32,
    color_type: u8,
    quality: u8,
    preset: u8,
    subsampling_420: bool,
    out_ptr: *mut *mut u8,
    out_len: *mut usize,
    err_msg: *mut *mut c_char,
) -> PixoStatus {
    clear_error(err_msg);

    if data_ptr.is_null() || out_ptr.is_null() || out_len.is_null() {
        set_error(err_msg, "null pointer argument".to_string());
        return PixoStatus::InvalidArg;
    }

    if quality == 0 || quality > 100 {
        set_error(err_msg, format!("invalid JPEG quality: {quality}, expected 1-100"));
        return PixoStatus::InvalidArg;
    }

    let result = catch_unwind(AssertUnwindSafe(|| {
        let color = color_type_from_u8_jpeg(color_type)?;

        let mut options = JpegOptions::from_preset(width, height, quality, preset);
        options.color_type = color;
        options.subsampling = if subsampling_420 {
            Subsampling::S420
        } else {
            Subsampling::S444
        };

        let data = unsafe { std::slice::from_raw_parts(data_ptr, data_len) };
        match jpeg::encode(data, &options) {
            Ok(mut encoded) => {
                let ptr = encoded.as_mut_ptr();
                let len = encoded.len();
                std::mem::forget(encoded);
                unsafe {
                    *out_ptr = ptr;
                    *out_len = len;
                }
                Ok(())
            }
            Err(e) => Err(e.to_string()),
        }
    }));

    match result {
        Ok(Ok(())) => PixoStatus::Ok,
        Ok(Err(msg)) => {
            set_error(err_msg, msg);
            PixoStatus::EncodeError
        }
        Err(_) => {
            set_error(err_msg, "panic during JPEG encode".to_string());
            PixoStatus::Panic
        }
    }
}

/// Free a buffer previously returned by one of the `pixo_encode_*` functions.
#[no_mangle]
pub extern "C" fn pixo_free_buffer(ptr: *mut u8, len: usize) {
    if ptr.is_null() || len == 0 {
        return;
    }
    unsafe {
        let _ = Vec::from_raw_parts(ptr, len, len);
    }
}

/// Free an error message string returned via `err_msg`.
#[no_mangle]
pub extern "C" fn pixo_free_cstring(ptr: *mut c_char) {
    if ptr.is_null() {
        return;
    }
    unsafe {
        let _ = CString::from_raw(ptr);
    }
}

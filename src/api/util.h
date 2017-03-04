/* purple
 *
 * Purple is the legal property of its developers, whose names are too numerous
 * to list here.  Please refer to the COPYRIGHT file distributed with this
 * source distribution.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02111-1301  USA
 */

#ifndef _FACEBOOK_UTIL_H_
#define _FACEBOOK_UTIL_H_

/**
 * SECTION:util
 * @section_id: facebook-util
 * @short_description: <filename>util.h</filename>
 * @title: General Utilities
 *
 * The general utilities.
 */

#include <glib.h>

/**
 * FB_UTIL_DEBUG_INFO:
 *
 * Shortcut #GLogLevelFlags for unsafe and verbose info messages.
 */
#define FB_UTIL_DEBUG_INFO ( \
		FB_UTIL_DEBUG_FLAG_UNSAFE | \
        FB_UTIL_DEBUG_FLAG_VERBOSE | \
        G_LOG_LEVEL_INFO \
	)

/**
 * FB_UTIL_ERROR:
 *
 * The #GQuark of the domain of utility errors.
 */
#define FB_UTIL_ERROR  fb_util_error_quark()

/**
 * FbUtilDebugFlags:
 * @FB_UTIL_DEBUG_FLAG_UNSAFE: The message is unsafe.
 * @FB_UTIL_DEBUG_FLAG_VERBOSE: The message is verbose.
 * @FB_UTIL_DEBUG_FLAG_ALL: All of the flags.
 *
 * The debugging message flags. These flags are inserted on top of
 * a #PurpleDebugLevel.
 */
typedef enum
{
    FB_UTIL_DEBUG_FLAG_UNSAFE = 1 << 25,
    FB_UTIL_DEBUG_FLAG_VERBOSE = 1 << 26,
    FB_UTIL_DEBUG_FLAG_ALL = 3 << 25
} FbUtilDebugFlags;

/**
 * FbUtilError:
 * @FB_UTIL_ERROR_GENERAL: General failure.
 *
 * The error codes for the #FB_UTIL_ERROR domain.
 */
typedef enum
{
	FB_UTIL_ERROR_GENERAL
} FbUtilError;

/**
 * fb_util_error_quark:
 *
 * Gets the #GQuark of the domain of utility errors.
 *
 * Returns: The #GQuark of the domain.
 */
GQuark
fb_util_error_quark(void);

/**
 * fb_util_debug:
 * @level: The #GLogLevelFlags.
 * @format: The format string literal.
 * @...: The arguments for @format.
 *
 * Logs a debugging message. If the messages is unsafe or verbose,
 * apply the appropriate #FbUtilDebugFlags.
 */
void
fb_util_debug(GLogLevelFlags level, const gchar *format, ...)
              G_GNUC_PRINTF(2, 3);
              
/**
 * fb_util_vdebug:
 * @level: The #GLogLevelFlags.
 * @format: The format string literal.
 * @ap: The #va_list.
 *
 * Logs a debugging message. If the messages is unsafe or verbose,
 * apply the appropriate #FbUtilDebugFlags.
 */
void
fb_util_vdebug(GLogLevelFlags level, const gchar *format, va_list ap);

/**
 * fb_util_debug_misc:
 * @format: The format string literal.
 * @...: The arguments for @format.
 *
 * Logs a debugging message with the level of #PURPLE_DEBUG_MISC.
 */

void
fb_util_debug_misc(const gchar *format, ...)
                   G_GNUC_PRINTF(1, 2);
                   
/**
 * fb_util_debug_info:
 * @format: The format string literal.
 * @...: The arguments for @format.
 *
 * Logs a debugging message with the level of #PURPLE_DEBUG_INFO.
 */
void
fb_util_debug_info(const gchar *format, ...)
                   G_GNUC_PRINTF(1, 2);
                   
/**
 * fb_util_debug_warning:
 * @format: The format string literal.
 * @...: The arguments for @format.
 *
 * Logs a debugging message with the level of #PURPLE_DEBUG_WARNING.
 */
void
fb_util_debug_warning(const gchar *format, ...)
                      G_GNUC_PRINTF(1, 2);

/**
 * fb_util_debug_error:
 * @format: The format string literal.
 * @...: The arguments for @format.
 *
 * Logs a debugging message with the level of #PURPLE_DEBUG_ERROR.
 */
void
fb_util_debug_error(const gchar *format, ...)
                    G_GNUC_PRINTF(1, 2);

/**
 * fb_util_debug_fatal:
 * @format: The format string literal.
 * @...: The arguments for @format.
 *
 * Logs a debugging message with the level of #PURPLE_DEBUG_FATAL.
 */
void
fb_util_debug_fatal(const gchar *format, ...)
                    G_GNUC_PRINTF(1, 2);

/**
 * fb_util_debug_hexdump:
 * @level: The #GLogLevelFlags.
 * @bytes: The #GByteArray.
 * @format: The format string literal.
 * @...: The arguments for @format.
 *
 * Logs a hexdump of a #GByteArray. If the messages is unsafe or
 * verbose, apply the appropriate #FbUtilDebugFlags.
 */
void
fb_util_debug_hexdump(GLogLevelFlags level, const GByteArray *bytes,
                      const gchar *format, ...)
                      G_GNUC_PRINTF(3, 4);

/**
 * fb_util_get_locale:
 *
 * Gets the locale string (ex: en_US) from the system. The returned
 * string should be freed with #g_free() when no longer needed.
 *
 * Returns: The locale string.
 */
gchar *
fb_util_get_locale(void);

/**
 * fb_util_rand_alnum:
 * @len: The length of the string.
 *
 * Gets a random alphanumeric (A-Za-z0-9) string. This function should
 * *not* be relied on for cryptographic operations. The returned string
 * should be freed with #g_free() when no longer needed.
 *
 * Returns: The alphanumeric string.
 */
gchar *
fb_util_rand_alnum(guint len);

/**
 * fb_util_rand_uuid:
 *
 * Gets a random UUID string. The returned string should be freed with
 * #g_free() when no longer needed.
 *
 * Returns: The UUID string.
 */
gchar *
fb_util_rand_uuid(void);


/**
 * fb_util_strtest: (skip):
 * @str: The string.
 * @type: The #GAsciiType.
 *
 * Tests if the string only contains characters allowed by the
 * #GAsciiType. More than one type can be specified by ORing the types
 * together.
 *
 * Returns: #TRUE if the string only contains characters allowed by the
 *          #GAsciiType, otherwise #FALSE.
 */
gboolean
fb_util_strtest(const gchar *str, GAsciiType type);

/**
 * fb_util_zlib_test:
 * @bytes: The #GByteArray.
 *
 * Tests if the #GByteArray is zlib compressed.
 *
 * Returns: #TRUE if the #GByteArray is compressed, otherwise #FALSE.
 */
gboolean
fb_util_zlib_test(const GByteArray *bytes);

/**
 * fb_util_zlib_deflate:
 * @bytes: The #GByteArray.
 * @error: The return location for the #GError or #NULL.
 *
 * Deflates a #GByteArray with zlib. The returned #GByteArray should be
 * freed with #g_byte_array_free() when no longer needed.
 *
 * Returns: The deflated #GByteArray or #NULL on error.
 */
GByteArray *
fb_util_zlib_deflate(const GByteArray *bytes, GError **error);

/**
 * fb_util_zlib_inflate:
 * @bytes: The #GByteArray.
 * @error: The return location for the #GError or #NULL.
 *
 * Inflates a #GByteArray with zlib. The returned #GByteArray should be
 * freed with #g_byte_array_free() when no longer needed.
 *
 * Returns: The inflated #GByteArray or #NULL on error.
 */
GByteArray *
fb_util_zlib_inflate(const GByteArray *bytes, GError **error);

#endif /* _FACEBOOK_UTIL_H_ */

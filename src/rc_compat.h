/****************************************************************************\
*
*   MODULE: rc_compat.h
*
*   Distro/kernel compatibility shims for the RAIDCore driver.
*
*   Distro kernels (RHEL, SUSE) backport newer upstream APIs into older
*   version-numbered kernels, so LINUX_VERSION_CODE alone cannot be
*   trusted. Where possible we probe for the API itself (macro / struct
*   member) instead of relying on version checks.
*
\****************************************************************************/

#ifndef _RC_COMPAT_H
#define _RC_COMPAT_H

#include <linux/version.h>
#include <linux/timer.h>
#include <linux/blkdev.h>

/*
 * timer_container_of() replaced from_timer() upstream in v6.16, but
 * distro kernels (e.g. RHEL 9.x) backported it into their 5.14 trees
 * and dropped from_timer() entirely. Provide the new name on kernels
 * that only have the old macro so call sites can use
 * timer_container_of() unconditionally.
 */
#ifndef timer_container_of
#define timer_container_of(var, callback_timer, timer_fieldname) \
		from_timer(var, callback_timer, timer_fieldname)
#endif

/*
 * blk_queue_max_hw_sectors() was removed upstream in v5.16 in favour of
 * writing struct queue_limits directly; RHEL 9 kernels made the same
 * change inside their 5.14 backports.  rc_queue_set_max_hw_sectors()
 * hides the difference.
 */
#if defined(RHEL_RELEASE_CODE)
#  if RHEL_RELEASE_CODE >= RHEL_RELEASE_VERSION(9, 0)
#    define RC_QUEUE_HAS_DIRECT_LIMITS 1
#  endif
#elif LINUX_VERSION_CODE >= KERNEL_VERSION(5, 16, 0)
#  define RC_QUEUE_HAS_DIRECT_LIMITS 1
#endif

static inline void
rc_queue_set_max_hw_sectors(struct request_queue *q, unsigned int max_sectors)
{
#if defined(RC_QUEUE_HAS_DIRECT_LIMITS)
	q->limits.max_hw_sectors = max_sectors;
#else
	blk_queue_max_hw_sectors(q, max_sectors);
#endif
}

#endif /* _RC_COMPAT_H */

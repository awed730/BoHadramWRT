# SPDX-License-Identifier: GPL-2.0-only
#
# Copyright (C) 2006-2010 OpenWrt.org
# Copyright (C) 2016 LEDE Project

ifneq ($(__rules_inc),1)
__rules_inc=1

ifeq ($(DUMP),)
  -include $(TOPDIR)/.config
endif
include $(TOPDIR)/include/debug.mk
include $(TOPDIR)/include/verbose.mk

ifneq ($(filter check,$(MAKECMDGOALS)),)
CHECK:=1
DUMP:=1
endif

export TMP_DIR:=$(TOPDIR)/tmp
export TMPDIR:=$(TMP_DIR)

##@
# @brief Strip quotes `"` and pounds `#` from string.
#
# @param 1: String.
##
qstrip=$(strip $(subst ",,$(1)))
#"))

empty:=
space:= $(empty) $(empty)
comma:=,
pound:=\#
##@
# @brief Merge strings by removing spaces.
#
# @param 1: String.
##
merge=$(subst $(space),,$(1))
##@
# @brief Get hash sum of variable list.
#
# @param 1: List of variable names.
##
confvar=$(shell echo '$(foreach v,$(1),$(v)=$(subst ','\'',$($(v))))' | $(MKHASH) md5)
##@
# @brief Strip last extension from file name.
#
# @param 1: File name.
##
strip_last=$(patsubst %.$(lastword $(subst .,$(space),$(1))),%,$(1))

paren_left = (
paren_right = )
chars_lower = a b c d e f g h i j k l m n o p q r s t u v w x y z
chars_upper = A B C D E F G H I J K L M N O P Q R S T U V W X Y Z

define sep

endef

define newline


endef

__tr_list = $(join $(join $(1),$(foreach char,$(1),$(comma))),$(2))
__tr_head_stripped = $(subst $(space),,$(foreach cv,$(call __tr_list,$(1),$(2)),$$$(paren_left)subst$(cv)$(comma)))
__tr_head = $(subst $(paren_left)subst,$(paren_left)subst$(space),$(__tr_head_stripped))
__tr_tail = $(subst $(space),,$(foreach cv,$(1),$(paren_right)))
__tr_template = $(__tr_head)$$(1)$(__tr_tail)

##@
# @brief Convert string characters to upper.
##
$(eval toupper = $(call __tr_template,$(chars_lower),$(chars_upper)))
##@
# @brief Convert string characters to lower.
##
$(eval tolower = $(call __tr_template,$(chars_upper),$(chars_lower)))

##@
# @brief Abbreviate version. Truncate to 8 characters.
##
version_abbrev = $(if $(if $(CHECK),,$(DUMP)),$(1),$(shell printf '%.8s' $(1)))

_SINGLE=export MAKEFLAGS=$(space);
CFLAGS:=
ARCH:=$(subst i486,i386,$(subst i586,i386,$(subst i686,i386,$(call qstrip,$(CONFIG_ARCH)))))
ARCH_PACKAGES:=$(call qstrip,$(CONFIG_TARGET_ARCH_PACKAGES))
BOARD:=$(call qstrip,$(CONFIG_TARGET_BOARD))
SUBTARGET:=$(call qstrip,$(CONFIG_TARGET_SUBTARGET))
TARGET_OPTIMIZATION:=$(call qstrip,$(CONFIG_TARGET_OPTIMIZATION))
TARGET_SUFFIX=$(call qstrip,$(CONFIG_TARGET_SUFFIX))
BUILD_SUFFIX:=$(call qstrip,$(CONFIG_BUILD_SUFFIX))
SUBDIR:=$(patsubst $(TOPDIR)/%,%,${CURDIR})
BUILD_SUBDIR:=$(patsubst $(TOPDIR)/%,%,${CURDIR})
NPROC=$(shell sysctl -n hw.ncpu 2>/dev/null || nproc)
export SHELL:=/usr/bin/env bash

IS_PACKAGE_BUILD := $(if $(filter package/%,$(BUILD_SUBDIR)),1)

OPTIMIZE_FOR_CPU=$(subst i386,i486,$(ARCH))

ifneq (,$(findstring $(ARCH) , aarch64 aarch64_be powerpc ))
  FPIC:=-DPIC -fPIC
else
  FPIC:=-DPIC -fpic
endif

HOST_FPIC:=-DPIC -fPIC

ARCH_SUFFIX:=$(call qstrip,$(CONFIG_CPU_TYPE))
GCC_ARCH:=

ifneq ($(ARCH_SUFFIX),)
  ARCH_SUFFIX:=_$(ARCH_SUFFIX)
endif
ifneq ($(filter -march=armv%,$(TARGET_OPTIMIZATION)),)
  GCC_ARCH:=$(patsubst -march=%,%,$(filter -march=armv%,$(TARGET_OPTIMIZATION)))
endif
ifdef CONFIG_HAS_SPE_FPU
  TARGET_SUFFIX:=$(TARGET_SUFFIX)spe
endif
ifdef CONFIG_MIPS64_ABI
  ifneq ($(CONFIG_MIPS64_ABI_O32),y)
     ARCH_SUFFIX:=$(ARCH_SUFFIX)_$(call qstrip,$(CONFIG_MIPS64_ABI))
  endif
endif

DEFAULT_SUBDIR_TARGETS:=clean download prepare compile update refresh prereq dist distcheck configure check check-depends

##@
# @brief Create default targets.
#
# Targets are created from @DEFAULT_SUBDIR_TARGETS and input argument lists.
#
# @param 1: Additional targets list.
##
define DefaultTargets
$(foreach t,$(DEFAULT_SUBDIR_TARGETS) $(1),
  .$(t):
  $(t): .$(t)
  .PHONY: $(t) .$(t)
)
endef

DL_DIR=$(if $(call qstrip,$(CONFIG_DOWNLOAD_FOLDER)),$(call qstrip,$(CONFIG_DOWNLOAD_FOLDER)),$(TOPDIR)/dl)$(if $(DL_SUBDIR),/$(DL_SUBDIR))
OUTPUT_DIR:=$(if $(call qstrip,$(CONFIG_BINARY_FOLDER)),$(call qstrip,$(CONFIG_BINARY_FOLDER)),$(TOPDIR)/bin)
BIN_DIR:=$(OUTPUT_DIR)/targets/$(BOARD)/$(SUBTARGET)
INCLUDE_DIR:=$(TOPDIR)/include
SCRIPT_DIR:=$(TOPDIR)/scripts
BUILD_DIR_BASE:=$(TOPDIR)/build_dir
ifeq ($(CONFIG_EXTERNAL_TOOLCHAIN),)
  GCCV:=$(call qstrip,$(CONFIG_GCC_VERSION))
  LIBC:=$(call qstrip,$(CONFIG_LIBC))
  REAL_GNU_TARGET_NAME=$(OPTIMIZE_FOR_CPU)-openwrt-linux$(if $(TARGET_SUFFIX),-$(TARGET_SUFFIX))
  GNU_TARGET_NAME=$(OPTIMIZE_FOR_CPU)-openwrt-linux
  DIR_SUFFIX:=_$(LIBC)$(if $(CONFIG_arm),_eabi)
  BIN_DIR:=$(BIN_DIR)$(if $(CONFIG_USE_MUSL),,-$(LIBC))
  TARGET_DIR_NAME = target-$(ARCH)$(ARCH_SUFFIX)$(DIR_SUFFIX)$(if $(BUILD_SUFFIX),_$(BUILD_SUFFIX))
  TOOLCHAIN_DIR_NAME = toolchain-$(ARCH)$(ARCH_SUFFIX)_gcc-$(GCCV)$(DIR_SUFFIX)
else
  ifeq ($(CONFIG_NATIVE_TOOLCHAIN),)
    GNU_TARGET_NAME=$(call qstrip,$(CONFIG_TARGET_NAME))
  else
    GNU_TARGET_NAME=$(shell gcc -dumpmachine)
  endif
  REAL_GNU_TARGET_NAME=$(GNU_TARGET_NAME)
  LIBC:=$(call qstrip,$(CONFIG_LIBC))
  TARGET_DIR_NAME:=target-$(GNU_TARGET_NAME)_$(LIBC)$(if $(BUILD_SUFFIX),_$(BUILD_SUFFIX))
  TOOLCHAIN_DIR_NAME:=toolchain-$(GNU_TARGET_NAME)
endif

ifeq ($(or $(CONFIG_EXTERNAL_TOOLCHAIN),$(CONFIG_TARGET_uml)),)
  iremap = -f$(if $(CONFIG_REPRODUCIBLE_DEBUG_INFO),file,macro)-prefix-map=$(1)=$(2)
endif

PACKAGE_DIR?=$(BIN_DIR)/packages
PACKAGE_DIR_ALL?=$(TOPDIR)/staging_dir/packages/$(BOARD)
BUILD_DIR:=$(BUILD_DIR_BASE)/$(TARGET_DIR_NAME)
STAGING_DIR:=$(TOPDIR)/staging_dir/$(TARGET_DIR_NAME)
BUILD_DIR_TOOLCHAIN:=$(BUILD_DIR_BASE)/$(TOOLCHAIN_DIR_NAME)
TOOLCHAIN_DIR:=$(TOPDIR)/staging_dir/$(TOOLCHAIN_DIR_NAME)
STAMP_DIR:=$(BUILD_DIR)/stamp
STAMP_DIR_HOST=$(BUILD_DIR_HOST)/stamp
TARGET_ROOTFS_DIR?=$(if $(call qstrip,$(CONFIG_TARGET_ROOTFS_DIR)),$(call qstrip,$(CONFIG_TARGET_ROOTFS_DIR)),$(BUILD_DIR))
TARGET_DIR:=$(TARGET_ROOTFS_DIR)/root-$(BOARD)
STAGING_DIR_ROOT:=$(STAGING_DIR)/root-$(BOARD)
STAGING_DIR_IMAGE:=$(STAGING_DIR)/image
BUILD_LOG_DIR:=$(if $(call qstrip,$(CONFIG_BUILD_LOG_DIR)),$(call qstrip,$(CONFIG_BUILD_LOG_DIR)),$(TOPDIR)/logs)
PKG_INFO_DIR := $(STAGING_DIR)/pkginfo

BUILD_DIR_HOST:=$(if $(IS_PACKAGE_BUILD),$(BUILD_DIR_BASE)/hostpkg,$(BUILD_DIR_BASE)/host)
STAGING_DIR_HOST:=$(abspath $(STAGING_DIR)/../host)
STAGING_DIR_HOSTPKG:=$(abspath $(STAGING_DIR)/../hostpkg)

TARGET_PATH:=$(subst $(space),:,$(filter-out .,$(filter-out ./,$(subst :,$(space),$(PATH)))))
TARGET_INIT_PATH:=$(call qstrip,$(CONFIG_TARGET_INIT_PATH))
TARGET_INIT_PATH:=$(if $(TARGET_INIT_PATH),$(TARGET_INIT_PATH),/usr/sbin:/sbin:/usr/bin:/bin)
TARGET_CFLAGS:=$(TARGET_OPTIMIZATION)$(if $(CONFIG_DEBUG), -g3) $(call qstrip,$(CONFIG_EXTRA_OPTIMIZATION))
TARGET_CXXFLAGS = $(TARGET_CFLAGS)
TARGET_ASFLAGS_DEFAULT = $(TARGET_CFLAGS)
TARGET_ASFLAGS = $(TARGET_ASFLAGS_DEFAULT)
ifneq ($(CONFIG_EXTERNAL_TOOLCHAIN),)
LIBGCC_S_PATH=$(realpath $(wildcard $(call qstrip,$(CONFIG_LIBGCC_ROOT_DIR))/$(call qstrip,$(CONFIG_LIBGCC_FILE_SPEC))))
LIBGCC_S=$(if $(LIBGCC_S_PATH),-L$(dir $(LIBGCC_S_PATH)) -lgcc_s)
LIBGCC_A=$(realpath $(lastword $(wildcard $(dir $(LIBGCC_S_PATH))/gcc/*/*/libgcc.a)))
else
LIBGCC_A=$(lastword $(wildcard $(TOOLCHAIN_DIR)/lib/gcc/*/*/libgcc.a))
LIBGCC_S=$(if $(wildcard $(TOOLCHAIN_DIR)/lib/libgcc_s.so),-L$(TOOLCHAIN_DIR)/lib -lgcc_s,$(LIBGCC_A))
endif

ifeq ($(CONFIG_ARCH_64BIT),y)
  LIB_SUFFIX:=64
endif

ifndef DUMP
  ifeq ($(CONFIG_EXTERNAL_TOOLCHAIN),)
    -include $(TOOLCHAIN_DIR)/info.mk
    export GCC_HONOUR_COPTS:=0
    TARGET_CROSS:=$(if $(TARGET_CROSS),$(TARGET_CROSS),$(OPTIMIZE_FOR_CPU)-openwrt-linux$(if $(TARGET_SUFFIX),-$(TARGET_SUFFIX))-)
    TOOLCHAIN_ROOT_DIR:=$(TOPDIR)/staging_dir/$(TOOLCHAIN_DIR_NAME)
    TOOLCHAIN_BIN_DIRS:=$(TOOLCHAIN_ROOT_DIR)/bin
    TOOLCHAIN_INC_DIRS:=$(TOOLCHAIN_ROOT_DIR)/usr/include $(TOOLCHAIN_ROOT_DIR)/include
    TOOLCHAIN_LIB_DIRS:=$(TOOLCHAIN_ROOT_DIR)/usr/lib $(TOOLCHAIN_ROOT_DIR)/lib
    TARGET_CFLAGS+= -fhonour-copts
    ifeq ($(CONFIG_USE_MUSL),y)
      TOOLCHAIN_INC_DIRS+= $(TOOLCHAIN_DIR)/include/fortify
    endif
  else
    ifeq ($(CONFIG_NATIVE_TOOLCHAIN),)
      -include $(TOOLCHAIN_DIR)/info.mk
      TARGET_CROSS:=$(call qstrip,$(CONFIG_TOOLCHAIN_PREFIX))
      TOOLCHAIN_ROOT_DIR:=$(call qstrip,$(CONFIG_TOOLCHAIN_ROOT))
      TOOLCHAIN_BIN_DIRS:=$(patsubst ./%,$(TOOLCHAIN_ROOT_DIR)/%,$(call qstrip,$(CONFIG_TOOLCHAIN_BIN_PATH)))
      TOOLCHAIN_INC_DIRS:=$(patsubst ./%,$(TOOLCHAIN_ROOT_DIR)/%,$(call qstrip,$(CONFIG_TOOLCHAIN_INC_PATH)))
      TOOLCHAIN_LIB_DIRS:=$(patsubst ./%,$(TOOLCHAIN_ROOT_DIR)/%,$(call qstrip,$(CONFIG_TOOLCHAIN_LIB_PATH)))
    endif
  endif
  ifneq ($(TOOLCHAIN_BIN_DIRS),)
    TARGET_PATH:=$(subst $(space),:,$(TOOLCHAIN_BIN_DIRS)):$(TARGET_PATH)
  endif
  ifneq ($(TOOLCHAIN_INC_DIRS),)
    TARGET_CPPFLAGS+= $(patsubst %,-I%,$(TOOLCHAIN_INC_DIRS))
  endif
  ifneq ($(TOOLCHAIN_LIB_DIRS),)
    TARGET_LDFLAGS+= $(patsubst %,-L%,$(TOOLCHAIN_LIB_DIRS))
  endif
endif

TARGET_LINKER?=bfd
TARGET_LDFLAGS+= -fuse-ld=$(TARGET_LINKER)

TARGET_PATH_PKG:=$(STAGING_DIR)/host/bin:$(STAGING_DIR_HOSTPKG)/bin:$(TARGET_PATH)

ifeq ($(CONFIG_SOFT_FLOAT),y)
  SOFT_FLOAT_CONFIG_OPTION:=--with-float=soft
  ifeq ($(CONFIG_arm),y)
    TARGET_CFLAGS+= -mfloat-abi=soft
  else
    TARGET_CFLAGS+= -msoft-float
  endif
else
  SOFT_FLOAT_CONFIG_OPTION:=
  ifeq ($(CONFIG_arm),y)
    TARGET_CFLAGS+= -mfloat-abi=hard
  endif
endif

export ORIG_PATH:=$(if $(ORIG_PATH),$(ORIG_PATH),$(PATH))
export PATH:=$(TARGET_PATH)
export STAGING_DIR STAGING_DIR_HOST STAGING_DIR_HOSTPKG
export SH_FUNC:=. $(INCLUDE_DIR)/shell.sh;

PKG_CONFIG:=$(STAGING_DIR_HOST)/bin/pkg-config

export PKG_CONFIG

HOST_FLAGS_OPT:=$(call qstrip,$(CONFIG_HOST_FLAGS_OPT))
HOST_FLAGS_STRIP:=$(call qstrip,$(CONFIG_HOST_FLAGS_STRIP))
HOST_EXTRA_CFLAGS:=$(call qstrip,$(CONFIG_HOST_EXTRA_CFLAGS))
HOST_EXTRA_CXXFLAGS:=$(call qstrip,$(CONFIG_HOST_EXTRA_CXXFLAGS))
HOST_EXTRA_CPPFLAGS:=$(call qstrip,$(CONFIG_HOST_EXTRA_CPPFLAGS))
HOST_EXTRA_LDFLAGS:=$(call qstrip,$(CONFIG_HOST_EXTRA_LDFLAGS))

HOSTCC:=$(STAGING_DIR_HOST)/bin/gcc
HOSTCXX:=$(STAGING_DIR_HOST)/bin/g++
HOST_CPPFLAGS:=$(strip -I$(STAGING_DIR_HOST)/include $(if $(IS_PACKAGE_BUILD),-I$(STAGING_DIR_HOSTPKG)/include -I$(STAGING_DIR)/host/include) $(HOST_EXTRA_CPPFLAGS))
HOST_CFLAGS:=$(strip $(HOST_FLAGS_OPT) $(HOST_EXTRA_CFLAGS) $(HOST_CPPFLAGS) $(HOST_FLAGS_STRIP))
HOST_CXXFLAGS:=$(strip $(HOST_CFLAGS) $(HOST_EXTRA_CXXFLAGS))
HOST_LDFLAGS:=$(strip -L$(STAGING_DIR_HOST)/lib $(if $(IS_PACKAGE_BUILD),-L$(STAGING_DIR_HOSTPKG)/lib -L$(STAGING_DIR)/host/lib) $(HOST_EXTRA_LDFLAGS) $(HOST_FLAGS_STRIP))

BUILD_KEY=$(TOPDIR)/key-build
BUILD_KEY_APK_SEC=$(TOPDIR)/private-key.pem
BUILD_KEY_APK_PUB=$(TOPDIR)/public-key.pem

FAKEROOT:=$(STAGING_DIR_HOST)/bin/fakeroot

TARGET_AR:=$(TARGET_CROSS)gcc-ar
TARGET_RANLIB:=$(TARGET_CROSS)gcc-ranlib
TARGET_NM:=$(TARGET_CROSS)gcc-nm
TARGET_CC:=$(TARGET_CROSS)gcc
TARGET_CXX:=$(TARGET_CROSS)g++
TARGET_LD:=$(TARGET_CROSS)ld.$(TARGET_LINKER)
KPATCH:=$(SCRIPT_DIR)/patch-kernel.sh
FILECMD:=$(STAGING_DIR_HOST)/bin/file
SED:=$(STAGING_DIR_HOST)/bin/sed -i -e
ESED:=$(STAGING_DIR_HOST)/bin/sed -E -i -e
MKHASH:=$(STAGING_DIR_HOST)/bin/mkhash
# MKHASH is used in /scripts, so we export it here.
export MKHASH
CP:=cp -fpR
LN:=ln -sf
XARGS:=xargs -r

BASH:=bash
TAR:=tar
FIND:=find
PATCH:=patch
PYTHON:=python3

ifeq ($(HOST_OS),Darwin)
  TRUE:=/usr/bin/env gtrue
  FALSE:=/usr/bin/env gfalse
else
  TRUE:=/usr/bin/env true
  FALSE:=/usr/bin/env false
endif

INSTALL_BIN:=install -m0755
INSTALL_SUID:=install -m4755
INSTALL_DIR:=install -d -m0755
INSTALL_DATA:=install -m0644
INSTALL_CONF:=install -m0600

TARGET_CC_NOCACHE:=$(TARGET_CC)
TARGET_CXX_NOCACHE:=$(TARGET_CXX)
HOSTCC_NOCACHE:=$(HOSTCC)
HOSTCXX_NOCACHE:=$(HOSTCXX)
export TARGET_CC_NOCACHE
export TARGET_CXX_NOCACHE
export HOSTCC_NOCACHE
export HOSTCXX_NOCACHE

ifneq ($(CONFIG_CCACHE),)
  TARGET_CC:= ccache $(TARGET_CC)
  TARGET_CXX:= ccache $(TARGET_CXX)
  HOSTCC:= ccache $(HOSTCC)
  HOSTCXX:= ccache $(HOSTCXX)
  export CCACHE_NOHASHDIR:=true
  export CCACHE_NOCOMPRESS:=true
  export CCACHE_BASEDIR:=$(TOPDIR)
  export CCACHE_DIR:=$(if $(call qstrip,$(CONFIG_CCACHE_DIR)),$(call qstrip,$(CONFIG_CCACHE_DIR)),$(TOPDIR)/.ccache)
  export CCACHE_COMPILERCHECK:=%compiler% -v -c
endif

TARGET_CONFIGURE_OPTS = \
  AR="$(TARGET_AR)" \
  AS="$(TARGET_CC) -c $(TARGET_ASFLAGS)" \
  LD="$(TARGET_LD)" \
  NM="$(TARGET_NM)" \
  CC="$(TARGET_CC)" \
  GCC="$(TARGET_CC)" \
  CXX="$(TARGET_CXX)" \
  RANLIB="$(TARGET_RANLIB)" \
  STRIP=$(TARGET_CROSS)strip \
  OBJCOPY=$(TARGET_CROSS)objcopy \
  OBJDUMP=$(TARGET_CROSS)objdump \
  SIZE=$(TARGET_CROSS)size

# strip an entire directory
ifneq ($(CONFIG_NO_STRIP),)
  RSTRIP:=:
  STRIP:=:
else
  ifneq ($(CONFIG_USE_STRIP),)
    STRIP:=$(TARGET_CROSS)strip $(call qstrip,$(CONFIG_STRIP_ARGS))
  else
    ifneq ($(CONFIG_USE_SSTRIP),)
      STRIP:=$(STAGING_DIR_HOST)/bin/sstrip $(if $(CONFIG_SSTRIP_DISCARD_TRAILING_ZEROES),-z)
    endif
  endif
  RSTRIP= \
    export CROSS="$(TARGET_CROSS)" \
		$(if $(PKG_BUILD_ID),KEEP_BUILD_ID=1) \
		$(if $(CONFIG_KERNEL_KALLSYMS),NO_RENAME=1) \
		$(if $(CONFIG_KERNEL_PROFILING),KEEP_SYMBOLS=1); \
    NM="$(TARGET_CROSS)nm" \
    STRIP="$(STRIP)" \
    STRIP_KMOD="$(SCRIPT_DIR)/strip-kmod.sh" \
    PATCHELF="$(STAGING_DIR_HOST)/bin/patchelf" \
    $(SCRIPT_DIR)/rstrip.sh
endif

NINJA = \
	MAKEFLAGS="$(MAKE_JOBSERVER)" \
	$(STAGING_DIR_HOST)/bin/ninja \
		$(if $(findstring c,$(OPENWRT_VERBOSE)),-v) \
		$(if $(MAKE_JOBSERVER),,-j1)

ifeq ($(CONFIG_IPV6),y)
  DISABLE_IPV6:=
else
  DISABLE_IPV6:=--disable-ipv6
endif

TAR_OPTIONS:=-xf -

ifeq ($(CONFIG_BUILD_LOG),y)
  BUILD_LOG:=1
endif

export BISON_PKGDATADIR:=$(STAGING_DIR_HOST)/share/bison
export HOST_GNULIB_SRCDIR:=$(STAGING_DIR_HOST)/share/gnulib
export M4:=$(STAGING_DIR_HOST)/bin/m4

##@
# @brief Slugify variable name and prepend suffix.
##
define shvar
V_$(subst .,_,$(subst -,_,$(subst /,_,$(1))))
endef

##@
# @brief Create and export variable, set to function result.
#
# @param 1: Function name. Used as variable name, prepended with `V_`.
##
define shexport
export $(call shvar,$(1))=$$(call $(1))
endef

##@
# @brief Support 64 bit tine in C code.
#
# Test support for 64-bit time with C code from largefile.m4 provided by GNU Gnulib
# the value is `y` when successful and `` otherwise
##
define YEAR_2038
$(shell \
  mkdir -p $(TMP_DIR); \
  echo '$(pound) include <time.h>' > $(TMP_DIR)/year2038.c; \
  echo '$(pound) define LARGE_TIME_T ((time_t) (((time_t) 1 << 30) - 1 + 3 * ((time_t) 1 << 30)))' >> $(TMP_DIR)/year2038.c; \
  echo 'int verify_time_t_range[(LARGE_TIME_T / 65537 == 65535 && LARGE_TIME_T % 65537 == 0) ? 1 : -1];' >> $(TMP_DIR)/year2038.c; \
  echo 'int main (void) {return 0;}' >> $(TMP_DIR)/year2038.c; \
  $(HOSTCC) $(TMP_DIR)/year2038.c -o /dev/null 2>/dev/null && echo y && rm -f $(TMP_DIR)/year2038.c || rm -f $(TMP_DIR)/year2038.c; \
)
endef

##@
# @brief Execute commands under flock
#
# @param 1: The shell expression.
# @param 2: The lock name. If not given, the global lock will be used.
##
ifneq ($(wildcard $(STAGING_DIR_HOST)/bin/flock),)
  define locked
	SHELL= \
	flock \
		$(TMP_DIR)/.$(if $(2),$(strip $(2)),global).flock \
		-c '$(subst ','\'',$(1))'
  endef
else
  locked=$(1)
endif


##@
# @brief Recursively copy paths into another directory, purge dangling
# symlinks before.
#
# @param 1: File glob expression.
# @param 1: Destination directory.
##
define file_copy
	for src_dir in $(sort $(foreach d,$(wildcard $(1)),$(dir $(d)))); do \
		( cd $$src_dir; find -type f -or -type d ) | \
			( cd $(2); while :; do \
				read FILE; \
				[ -z "$$FILE" ] && break; \
				[ -L "$$FILE" ] || continue; \
				echo "Removing symlink $(2)/$$FILE"; \
				rm -f "$$FILE"; \
			done; ); \
	done; \
	$(CP) $(1) $(2)
endef

##@
# @brief Calculate sha256sum of any plain file within a given directory.
#
# @param 1: Input directory.
# @param 2: If set, recurse into subdirectories.
##
define sha256sums
	(cd $(1); find . $(if $(2),,-maxdepth 1) -type f -not -name 'sha256sums' -printf "%P\n" | sort | \
		xargs -r $(MKHASH) -n sha256 | sed -ne 's!^\(.*\) \(.*\)$$!\1 *\2!p' > sha256sums)
endef

##@
# @brief Retrieve file extension.
#
# @param 1: File name.
##
ext=$(word $(words $(subst ., ,$(1))),$(subst ., ,$(1)))

##@
# @brief Count Git commits of a package.
#
# @param 1: if non-empty: count commits since last ": [uU]pdate to "
#           or ": [bB]ump to " in commit message.
##
define commitcount
$(shell \
  if git log -1 >/dev/null 2>/dev/null; then \
    if [ -n "$(1)" ]; then \
      last_bump="$$(git log --pretty=format:'%h %s' . | \
        grep -m 1 -e ': [uU]pdate to ' -e ': [bB]ump to ' | \
        cut -f 1 -d ' ')"; \
    fi; \
    if [ -n "$$last_bump" ]; then \
      echo -n $$(($$(git rev-list --count "$$last_bump..HEAD" .) + 1)); \
    else \
      git rev-list --count HEAD .; \
    fi; \
  else \
    secs="$$(($(SOURCE_DATE_EPOCH) % 86400))"; \
    date="$$(date --utc --date="@$(SOURCE_DATE_EPOCH)" "+%y%m%d")"; \
    printf '%s.%05d' "$$date" "$$secs"; \
  fi; \
)
endef

##@
# @brief Get ABI version string, stripping `-`, `_` and `.`.
#
# @param 1: Version string.
##
abi_version_str = $(subst -,,$(subst _,,$(subst .,,$(1))))

COMMITCOUNT = $(if $(DUMP),0,$(call commitcount))
AUTORELEASE = $(if $(DUMP),0,$(call commitcount,1))

all:
FORCE: ;
.PHONY: FORCE

check: FORCE
	@true

val.%:
	@$(if $(filter undefined,$(origin $*)),\
		echo "$* undefined" >&2, \
		echo '$(subst ','"'"',$($*))' \
	)

var.%:
	@$(if $(filter undefined,$(origin $*)),\
		echo "$* undefined" >&2, \
		echo "$*='"'$(subst ','"'\"'\"'"',$($*))'"'" \
	)

endif #__rules_inc

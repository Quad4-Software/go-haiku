// Copyright 2014 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

//go:build gc
// +build gc

#include "textflag.h"

//
// System calls for 386, Haiku are implemented in runtime/syscall_haiku.go
//

TEXT ·sysvicall6(SB),NOSPLIT,$0-28
	JMP	syscall·sysvicall6(SB)

TEXT ·rawSysvicall6(SB),NOSPLIT,$0-28
	JMP	syscall·rawSysvicall6(SB)

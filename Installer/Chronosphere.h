/*
 *  Chronosphere.h
 *
 *  Copyright 2021-2022 vChewing Project (3-Clause BSD License).
 *  Derived from 2011-2022 OpenVanilla Project (MIT License).
 *  Some rights reserved. See "LICENSE.TXT" for details.
 */

@import Cocoa;

NS_ASSUME_NONNULL_BEGIN

// Determines if an app is translocated by Gatekeeper to a randomized path
// See https://weblog.rogueamoeba.com/2016/06/29/sierra-and-gatekeeper-path-randomization/
BOOL appBundleChronoshiftedToARandomizedPath(NSString *bundle);

NS_ASSUME_NONNULL_END

import { Router, type Request, type Response } from 'express';
import { authenticateJWT } from '../../middleware/auth.middleware';
import { ok } from '../../config/types';
import type { JwtAuthPayload } from '../../config/types';
import {
  resolveEffectiveBranchFilter,
  isRoleAllowedOverrideBranch,
} from '../../utils/rbac';

const testRoutes = Router();

testRoutes.get(
  '/rbac-scope',
  authenticateJWT,
  (req: Request, res: Response): void => {
    const user = req.user as JwtAuthPayload;

    const rawQuery: Record<string, any> = { ...(req.query ?? {}) };
    const effectiveFilter = resolveEffectiveBranchFilter(user, rawQuery);
    const canOverride = isRoleAllowedOverrideBranch(user.role);

    const qBranchId = typeof rawQuery['branchId'] === 'string' ? rawQuery['branchId'] : null;
    const qTenantId = typeof rawQuery['tenantId'] === 'string' ? rawQuery['tenantId'] : null;

    res.status(200).json(ok({
      role: user.role,
      userId: user.userId,
      tenantIdInToken: user.tenantId,
      branchIdInToken: user.branchId,
      inputQueryParams: {
        tenantId: qTenantId,
        branchId: qBranchId,
      },
      canOverrideBranchViaQuery: canOverride,
      enforcedOwnBranch: !canOverride,
      effectiveBranchFilter: effectiveFilter,
      ruleSource: 'resolveEffectiveBranchFilter@src/utils/rbac.ts',
      metadata: {
        enforcedOwnBranch: !canOverride,
        ruleSource: 'resolveEffectiveBranchFilter@src/utils/rbac.ts',
      },
    }));
  },
);

export default testRoutes;

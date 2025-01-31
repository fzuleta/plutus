{-# LANGUAGE RecordWildCards #-}

module Language.Marlowe.ACTUS.Model.INIT.StateInitializationModel where

import           Data.List                                              as L (filter, head)
import           Data.Maybe                                             (fromJust, fromMaybe, isJust, isNothing)
import           Data.Time.Calendar                                     (Day)
import           Language.Marlowe.ACTUS.Definitions.ContractState       (ContractStatePoly (ContractStatePoly, feac, ipac, ipcb, ipnr, isc, nsc, nt, prf, prnxt, sd, tmd))
import           Language.Marlowe.ACTUS.Definitions.ContractTerms       (CR, ContractTerms (..), Cycle (..), DCC,
                                                                         FEB (FEB_N), IPCB (IPCB_NT),
                                                                         SCEF (SE_0N0, SE_0NM, SE_I00, SE_I0M, SE_IN0, SE_INM),
                                                                         ScheduleConfig (..), n)
import           Language.Marlowe.ACTUS.Definitions.Schedule            (ShiftedDay (..), ShiftedSchedule)
import           Language.Marlowe.ACTUS.Model.Utility.ContractRoleSign  (contractRoleSign)
import           Language.Marlowe.ACTUS.Model.Utility.ScheduleGenerator (applyEOMC,
                                                                         generateRecurrentScheduleWithCorrections,
                                                                         minusCycle, plusCycle)
import           Language.Marlowe.ACTUS.Model.Utility.YearFraction      (yearFraction)

_S :: Day -> Cycle -> Day -> ScheduleConfig -> ShiftedSchedule
_S = generateRecurrentScheduleWithCorrections

r :: CR -> Double
r = contractRoleSign

y :: DCC -> Day -> Day -> Maybe Day -> Double
y = yearFraction

scef_xNx :: SCEF -> Bool
scef_xNx SE_0N0 = True
scef_xNx SE_0NM = True
scef_xNx SE_IN0 = True
scef_xNx SE_INM = True
scef_xNx _      = False

scef_Ixx :: SCEF -> Bool
scef_Ixx SE_IN0 = True
scef_Ixx SE_INM = True
scef_Ixx SE_I00 = True
scef_Ixx SE_I0M = True
scef_Ixx _      = False



_INIT_PAM :: Day -> Day -> Day -> Day -> ContractTerms -> ContractStatePoly Double Day
_INIT_PAM t0 tminus tfp_minus tfp_plus
  ContractTerms{..} =
    let
        _IED   = fromJust ct_IED
        _DCC   = fromJust ct_DCC
        _PRF   = fromJust ct_PRF
        _SCEF  = fromJust ct_SCEF
        _SCNT  = fromJust ct_SCNT
        _SCIP  = fromJust ct_SCIP

        tmd                                     = fromJust ct_MD
        nt
                | _IED > t0                     = 0.0
                | otherwise                     = r ct_CNTRL * fromJust ct_NT

        ipnr
                | _IED > t0                     = 0.0
                | otherwise                     = fromMaybe 0.0 ct_IPNR
        ipac
                | isNothing ct_IPNR             = 0.0
                | isJust ct_IPAC                = r ct_CNTRL * fromJust ct_IPAC
                | otherwise                     = (y _DCC tminus t0 ct_MD) * nt * ipnr
        feac
                | isNothing ct_FER              = 0.0
                | isJust ct_FEAC                = fromJust ct_FEAC
                | fromJust ct_FEB == FEB_N      = y _DCC tfp_minus t0 ct_MD * nt * fromJust ct_FER
                | otherwise                     = y _DCC tfp_minus t0 ct_MD / y _DCC tfp_minus tfp_plus ct_MD * fromJust ct_FER

        nsc
                | scef_xNx _SCEF                = _SCNT
                | otherwise                     = 1.0

        isc
                | scef_Ixx _SCEF                = _SCIP
                | otherwise                     = 1.0

        prf                                     = _PRF

        sd                                      = t0
    in ContractStatePoly { prnxt = 0.0, ipcb = 0.0, tmd = tmd, nt = nt, ipnr = ipnr, ipac = ipac, feac = feac, nsc = nsc, isc = isc, prf = prf, sd = sd }

_INIT_LAM :: Day -> Day -> Day -> Day -> Day -> ContractTerms -> ContractStatePoly Double Day
_INIT_LAM t0 tminus _ tfp_minus tfp_plus
  terms@ContractTerms{..} =
    let
        _IED' = fromJust ct_IED
        _DCC' = fromJust ct_DCC

        -- TMD
        -- maybeTMinus
        --             | isJust _PRANX && ((fromJust _PRANX) >= t0) = _PRANX
        --             | (_IED' `plusCycle` fromJust ct_PRCL) >= t0 = Just $ _IED' `plusCycle` fromJust ct_PRCL
        --             | otherwise                           = Just tpr_minus
        -- tmd
        --         | isJust ct_MD = fromJust ct_MD
        --         | otherwise = fromJust maybeTMinus `plusCycle` (fromJust ct_PRCL) { n = ((ceiling ((fromJust ct_NT) / (fromJust ct_PRNXT))) * (n (fromJust ct_PRCL))) }

        -- TMD
        tmd
          | isJust ct_MD = fromJust ct_MD
          | otherwise =
            let
              (lastEvent, remainingPeriods) =
                if isJust ct_PRANX && fromJust ct_PRANX < ct_SD then
                  let
                    previousEvents   = (\s -> _S s (fromJust ct_PRCL) ct_SD scfg ) <$> ct_PRANX
                    previousEvents'  = L.filter(\ShiftedDay{ calculationDay = calculationDay } -> calculationDay > (minusCycle ct_SD (fromJust ct_IPCL))) (fromMaybe [] previousEvents)
                    previousEvents'' = L.filter(\ShiftedDay{ calculationDay = calculationDay } -> calculationDay == ct_SD) previousEvents'
                    ShiftedDay{ calculationDay = lastEventCalcDay } = L.head previousEvents''
                  in
                    (lastEventCalcDay, (fromJust ct_NT) / (fromJust ct_PRNXT))
                else
                  -- TODO: check applicability for PRANX
                  (fromJust ct_PRANX, (fromJust ct_NT) / (fromJust ct_PRNXT) - 1)
              c@Cycle{ n = n } = fromJust ct_PRCL
              maturity = plusCycle lastEvent c { n = n * (round remainingPeriods) :: Integer}
            in
              applyEOMC lastEvent c (fromJust (eomc scfg)) maturity


        pam_init = _INIT_PAM t0 tminus tfp_minus tfp_plus terms

        -- PRNXT
        -- s
        --         | isJust ct_PRANX && ((fromJust ct_PRANX) > t0) = fromJust ct_PRANX
        --         | isNothing ct_PRANX && ((_IED' `plusCycle` fromJust ct_PRCL) > t0) = _IED' `plusCycle` fromJust ct_PRCL
        --         | otherwise = tpr_minus
        prnxt
                | isJust ct_PRNXT                 = fromJust ct_PRNXT
                {- ACTUS implementation
                -- | otherwise                     = (fromJust ct_NT) * (1.0 / (fromIntegral $ ((ceiling (y _DCC' s tmd (Just tmd) / y _DCC' s (s `plusCycle` fromJust ct_PRCL) (Just tmd))) :: Integer)))
                -}

                -- Java implementation
                | otherwise = (fromJust ct_NT) / (fromIntegral (length $ fromJust ((\s -> _S s (fromJust ct_PRCL){ includeEndDay = True } tmd scfg ) <$> ct_PRANX)))
        -- IPCB
        ipcb
                | t0 < _IED'                    = 0.0
                | fromJust ct_IPCB == IPCB_NT     = r ct_CNTRL * fromJust ct_NT
                | otherwise                     = r ct_CNTRL * fromJust ct_IPCBA
    -- All is same as PAM except PRNXT, IPCB, and TMD
    in pam_init { prnxt = prnxt, ipcb = ipcb, tmd = tmd }

_INIT_NAM :: Day -> Day -> Day -> Day -> Day -> ContractTerms -> ContractStatePoly Double Day
_INIT_NAM t0 tminus _ tfp_minus tfp_plus
  terms@ContractTerms{..} =
    let
        _IED   = fromJust ct_IED
        _DCC   = fromJust ct_DCC
        _PRNXT = fromJust ct_PRNXT

        {-
        -- TMD
        -- maybeTMinus
                    -- | isJust ct_PRANX && fromJust ct_PRANX >= t0 = ct_PRANX
                    -- | (_IED `plusCycle` fromJust ct_PRCL) >= t0  = Just $ _IED `plusCycle` fromJust ct_PRCL
                    -- | otherwise                                  = Just tpr_minus
        -}

        tmd
                | isJust ct_MD = fromJust ct_MD
                | otherwise =
                  let
                    lastEvent =
                      if isJust ct_PRANX && (fromJust ct_PRANX) >= ct_SD then
                        fromJust ct_PRANX
                      else
                        if _IED `plusCycle` (fromJust ct_PRCL) >= ct_SD then
                          _IED `plusCycle` (fromJust ct_PRCL)
                        else
                          let previousEvents  = (\s -> _S s (fromJust ct_PRCL) ct_SD scfg ) <$> ct_PRANX
                              previousEvents'  = L.filter(\ShiftedDay{ calculationDay = calculationDay } -> calculationDay >= ct_SD ) (fromMaybe [] previousEvents)
                              previousEvents'' = L.filter(\ShiftedDay{ calculationDay = calculationDay } -> calculationDay == ct_SD) previousEvents'
                              ShiftedDay{ calculationDay = lastEventCalcDay } = L.head previousEvents''
                          in
                              lastEventCalcDay
                    yLastEventPlusPRCL = (y _DCC lastEvent (lastEvent `plusCycle` (fromJust ct_PRCL)) ct_MD)
                    redemptionPerCycle = _PRNXT - (yLastEventPlusPRCL * (fromJust ct_IPNR) * (fromJust ct_NT))
                    remainingPeriods = (ceiling ((fromJust ct_NT) / redemptionPerCycle)) - 1
                    c@Cycle{ n = n } = fromJust ct_PRCL
                    maturity = plusCycle lastEvent c { n = n * remainingPeriods}
                  in
                    applyEOMC lastEvent c (fromJust (eomc scfg)) maturity
                    {-
                -- | otherwise = fromJust maybeTMinus `plusCycle` (fromJust ct_PRCL) { n = ceiling((fromJust ct_NT) / (_PRNXT' - (fromJust ct_NT)  * (y _DCC' tminus (tminus `plusCycle` fromJust ct_PRCL) ct_MD) * fromJust ct_IPNR))}

                    -}
        -- PRNXT
        prnxt = _PRNXT

        -- IPCB
        ipcb
                | t0 < _IED                     = 0.0
                | fromJust ct_IPCB == IPCB_NT     = r ct_CNTRL * fromJust ct_NT
                | otherwise                     = r ct_CNTRL * fromJust ct_IPCBA

        pam_init = _INIT_PAM t0 tminus tfp_minus tfp_plus terms

    -- All is same as PAM except PRNXT and TMD, IPCB same as LAM
    in pam_init { prnxt = prnxt, ipcb = ipcb, tmd = tmd }

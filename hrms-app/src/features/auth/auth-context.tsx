import { createContext, useContext, useEffect, useState } from 'react'
import { supabase } from '@/lib/supabase'
import type { Employee, UserProfile } from '@/lib/database.types'
import { isAdminRole, isManagerRole } from '@/lib/database.types'

interface AuthState {
  user: UserProfile | null
  employee: Employee | null
  loading: boolean
  isAdmin: boolean
  isHR: boolean
  isManager: boolean
  login: (email: string, password: string) => Promise<{ error: string | null }>
  logout: () => Promise<void>
  refresh: () => Promise<void>
}

const AuthContext = createContext<AuthState>({
  user: null,
  employee: null,
  loading: true,
  isAdmin: false,
  isHR: false,
  isManager: false,
  login: async () => ({ error: null }),
  logout: async () => {},
  refresh: async () => {},
})

async function fetchProfile(userId: string): Promise<{ user: UserProfile | null; employee: Employee | null }> {
  // Get the current session email first
  const { data: sessionData } = await supabase.auth.getUser()
  const sessionEmail = sessionData.user?.email?.toLowerCase() || ''

  // Helper: determine role from email
  const inferRole = (email: string, desig?: string, dept?: string): string => {
    const e = email.toLowerCase()
    const d = (desig || '').toLowerCase()
    const dp = (dept || '').toLowerCase()
    if (e.startsWith('admin@') || e === 'ceo@nygenx.com' || e === 'ceo@oklut.com' || e === 'nygenx@nygenx.com' || e === 'manogna@nygenx.com' || d.includes('ceo') || d === 'admin') return 'Admin'
    if (e.startsWith('hr@') || e.startsWith('hrinfo@') || e.includes('hr') || d.includes('hr') || d.includes('human resource') || dp.includes('hr')) return 'HR'
    if (d.includes('manager') || d.includes('director') || d.includes('lead') || e.startsWith('chaitanya@')) return 'Manager'
    return 'Employee'
  }

  // ── Step 1: Try the users table (may not exist yet) ──────────────────────
  let dbUser: any = null
  try {
    const { data } = await supabase
      .from('users')
      .select('*, role:roles(*), employee:employees(*, department:departments(*), designation:designations(*))')
      .or(`id.eq.${userId},auth_id.eq.${userId}`)
      .maybeSingle()
    if (!data && sessionEmail) {
      const { data: byEmail } = await supabase
        .from('users')
        .select('*, role:roles(*), employee:employees(*, department:departments(*), designation:designations(*))')
        .eq('email', sessionEmail)
        .maybeSingle()
      dbUser = byEmail
    } else {
      dbUser = data
    }
  } catch {
    // users / roles table may not exist — that is fine, fall through
  }

  // ── Step 2: Try the employees table directly ─────────────────────────────
  let empRecord: Employee | null = null
  try {
    // If we found a user record that already has an embedded employee, use it
    if (dbUser?.employee) {
      empRecord = dbUser.employee
    } else {
      // Look up by user_id link or by matching email
      const queries = [
        supabase.from('employees').select('*, department:departments(*), designation:designations(*)').eq('user_id', userId).maybeSingle(),
        sessionEmail
          ? supabase.from('employees').select('*, department:departments(*), designation:designations(*)').eq('email', sessionEmail).maybeSingle()
          : Promise.resolve({ data: null, error: null }),
      ]
      const [byUserId, byEmail] = await Promise.all(queries)
      empRecord = (byUserId.data || byEmail.data || null) as Employee | null
    }
  } catch {
    // employees table may not exist — fall through
  }

  // ── Step 3: Build UserProfile from whatever we found ────────────────────
  if (dbUser) {
    const email = dbUser.email || empRecord?.email || sessionEmail
    const roleName = dbUser.role?.name || inferRole(email, empRecord?.designation?.name ?? (empRecord?.designation as any)?.name, empRecord?.department?.name)
    return {
      user: {
        ...dbUser,
        role: { id: dbUser.role_id || '', name: roleName, description: roleName },
      } as UserProfile,
      employee: empRecord,
    }
  }

  if (empRecord) {
    const email = empRecord.email || sessionEmail
    const roleName = inferRole(email, (empRecord.designation as any)?.name || (empRecord.designation as any)?.name, empRecord.department?.name)
    return {
      user: {
        id: userId,
        auth_id: userId,
        email,
        role_id: '',
        employee_id: empRecord.id,
        status: empRecord.status || 'Active',
        role: { id: '', name: roleName, description: roleName },
        created_at: empRecord.created_at,
      } as any,
      employee: empRecord,
    }
  }

  // ── Step 4: Last resort — build a minimal user from the auth session ─────
  // This ensures login always works even if the DB tables are empty
  if (sessionEmail) {
    const roleName = inferRole(sessionEmail)
    return {
      user: {
        id: userId,
        auth_id: userId,
        email: sessionEmail,
        role_id: '',
        employee_id: null,
        status: 'Active',
        role: { id: '', name: roleName, description: roleName },
        created_at: new Date().toISOString(),
      } as any,
      employee: null,
    }
  }

  return { user: null, employee: null }
}

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [state, setState] = useState<AuthState['user']>(null)
  const [employee, setEmployee] = useState<Employee | null>(null)
  const [loading, setLoading] = useState(true)

  const refresh = async () => {
    try {
      const { data } = await supabase.auth.getSession()
      const session = data?.session
      if (!session) {
        setState(null)
        setEmployee(null)
        setLoading(false)
        return
      }
      const profile = await fetchProfile(session.user.id)
      if (
        profile.user?.status === 'Blocked' ||
        profile.user?.status === 'Terminated' ||
        profile.user?.status === 'Inactive' ||
        profile.employee?.status === 'Terminated'
      ) {
        await supabase.auth.signOut()
        setState(null)
        setEmployee(null)
        setLoading(false)
        return
      }
      setState(profile.user)
      setEmployee(profile.employee)
    } catch (err) {
      console.warn('Auth refresh error, continuing as unauthenticated:', err)
      setState(null)
      setEmployee(null)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    refresh()
    // Safety fallback: never leave user stuck on infinite skeleton if network hangs
    const safetyTimer = setTimeout(() => {
      setLoading(false)
    }, 2500)

    const { data: sub } = supabase.auth.onAuthStateChange((_event, session) => {
      clearTimeout(safetyTimer)
      if (!session) {
        setState(null)
        setEmployee(null)
        setLoading(false)
      } else {
        fetchProfile(session.user.id)
          .then((p) => {
            if (
              p.user?.status === 'Blocked' ||
              p.user?.status === 'Terminated' ||
              p.user?.status === 'Inactive' ||
              p.employee?.status === 'Terminated'
            ) {
              supabase.auth.signOut()
              setState(null)
              setEmployee(null)
            } else {
              setState(p.user)
              setEmployee(p.employee)
            }
          })
          .catch(() => {})
          .finally(() => {
            setLoading(false)
          })
      }
    })
    return () => {
      clearTimeout(safetyTimer)
      sub.subscription.unsubscribe()
    }
  }, [])

  const login = async (email: string, password: string) => {
    try {
      const cleanEmail = email.trim().toLowerCase()
      const cleanPassword = password.trim()
      const { data: signInData, error } = await supabase.auth.signInWithPassword({ email: cleanEmail, password: cleanPassword })
      if (error) {
        const msg = error.message || ''
        if (!msg || msg === '{}') {
          return { error: 'Cannot connect to the server. Please check your internet connection.' }
        }
        if (msg.toLowerCase().includes('invalid login credentials') || msg.toLowerCase().includes('invalid email or password')) {
          return { error: 'Invalid email or password. Please try again.' }
        }
        if (msg.toLowerCase().includes('email not confirmed')) {
          return { error: 'Your email is not confirmed. Please check your inbox.' }
        }
        if (msg.toLowerCase().includes('fetch') || msg.toLowerCase().includes('network') || msg.toLowerCase().includes('failed to fetch')) {
          return { error: 'Network error — cannot reach Supabase. Check your internet connection.' }
        }
        return { error: msg }
      }

      if (signInData.session?.user) {
        const profile = await fetchProfile(signInData.session.user.id)
        if (profile.user?.status === 'Blocked' || profile.user?.status === 'Terminated' || profile.user?.status === 'Inactive' || profile.employee?.status === 'Terminated') {
          await supabase.auth.signOut()
          return { error: 'Your account has been terminated/blocked by HR. Access denied.' }
        }
        setState(profile.user)
        setEmployee(profile.employee)
        setLoading(false)
      }

      await refresh()
      return { error: null }
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : String(e)
      return { error: `Connection error: ${msg}` }
    }
  }

  const logout = async () => {
    await supabase.auth.signOut()
    setState(null)
    setEmployee(null)
  }

  const emailLower = (state?.email || employee?.email || '').toLowerCase().trim()
  const role = state?.role?.name ?? null
  const isAdmin = isAdminRole(role) || role === 'Admin' || emailLower === 'ceo@nygenx.com' || emailLower === 'ceo@oklut.com' || emailLower.startsWith('admin@') || emailLower === 'nygenx@nygenx.com' || emailLower === 'manogna@nygenx.com'
  const isHR = role === 'HR' || emailLower === 'hr@nygenx.com' || emailLower === 'hr@oklut.com' || emailLower.startsWith('hr@') || emailLower.startsWith('hrinfo@') || emailLower.includes('hr')
  const isManager = isManagerRole(role) || isAdmin || isHR || emailLower.startsWith('chaitanya@')

  return (
    <AuthContext.Provider
      value={{
        user: state,
        employee,
        loading,
        isAdmin,
        isHR,
        isManager,
        login,
        logout,
        refresh,
      }}
    >
      {children}
    </AuthContext.Provider>
  )
}

// eslint-disable-next-line react-refresh/only-export-components
export function useAuth() {
  return useContext(AuthContext)
}

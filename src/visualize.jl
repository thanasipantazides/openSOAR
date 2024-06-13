using GLMakie, Colors, GeometryBasics, LinearAlgebra
using SatelliteToolboxBase, SatelliteToolboxTransformations
using FileIO

# for live plotting (Observables), want a family of functions that plot 

function r_ecef_to_eci_from_obs(t_jd, iers_eops)
    # t_jd should get passed in as the .value of an 
    return r_ecef_to_eci(ITRF(), J2000(), t_jd, iers_eops)
end

function plot_power!(ax::Makie.Axis, t_jd_s, target_histories::Dict, soln::Dict)
    playhead = lift(t_jd_s) do t_jd_s
        t_0 = soln["time"][1]
        return t_jd_s - t_0
    end
    
    e_hist = soln["state"][19,:]
    
    lw = 2.0
    lines!(
        ax, 
        soln["time"] .- soln["time"][1],
        e_hist/3600,
        color=:yellow,
        linewidth=lw
    )

    vlines!(
        ax,
        playhead,
        color=:yellow,
        alpha=0.7,
        linewidth=1
    )
end

function plot_visibilities!(ax::Makie.Axis, t_jd_s, target_histories::Dict, soln::Dict)

    playhead = lift(t_jd_s) do t_jd_s
        t_0 = soln["time"][1]
        return t_jd_s - t_0
    end

    li = 1
    for (key, val) in target_histories
        t_0 = soln["time"][1]

        change = diff(val)
        starts = findall(i->(i > 0), change)
        stops = findall(i->(i < 0), change)
        if val[1] == 1
            starts = [1 starts]
        end 
        # println(starts)
        # println(stops)
        plotval = [Rect(soln["time"][starts[i]] - t_0, li - 1, soln["time"][stops[i] - 1] - soln["time"][starts[i]], 1) for i in 1:min(length(starts), length(stops))]

        poly!(
            ax,
            plotval,
            alpha=1.0,
            strokewidth=0.1,
            strokecolor=:white,
            label=key
        )

        li += 1
    end
    vlines!(
        ax,
        playhead,
        color=:yellow,
        alpha=0.7,
        linewidth=1
    )
end

function plot_detail!(ax::Makie.Axis, t_jd_s, soln::Dict)
    this_i = lift(t_jd_s) do t_jd_s
        (_,i) = findmin(x->abs(x - t_jd_s), soln["time"])
        return i
    end
    # x_hist = lift(this_i) do this_i
    #     t_0 = soln["time"][1]
    #     # return ([soln["time"][j] - t_0 for j in 1:this_i], [soln["state"][7,j] for j in 1:this_i])
    #     return Point2f[(soln["time"][j] - t_0,  soln["state"][7,j]) for j in 1:this_i]
    # end
    # y_hist = lift(this_i) do this_i
    #     t_0 = soln["time"][1]
    #     # return ([soln["time"][j] - t_0 for j in 1:this_i], [soln["state"][7,j] for j in 1:this_i])
    #     return Point2f[(soln["time"][j] - t_0,  soln["state"][8,j]) for j in 1:this_i]
    # end
    # z_hist = lift(this_i) do this_i
    #     t_0 = soln["time"][1]
    #     # return ([soln["time"][j] - t_0 for j in 1:this_i], [soln["state"][7,j] for j in 1:this_i])
    #     return Point2f[(soln["time"][j] - t_0,  soln["state"][9,j]) for j in 1:this_i]
    # end
    # x_hist = lift(this_i) do this_i
    #     return [soln["state"][7,j] for j in 1:this_i]
    # end

    x_hist = soln["state"][7,:]
    y_hist = soln["state"][8,:]
    z_hist = soln["state"][9,:]

    playhead = lift(t_jd_s) do t_jd_s
        t_0 = soln["time"][1]
        return t_jd_s - t_0
    end

    lw = 1.0
    lines!(
        ax, 
        soln["time"] .- soln["time"][1],
        x_hist,
        color=:red,
        linewidth=lw
    )
    lines!(
        ax, 
        soln["time"] .- soln["time"][1],
        y_hist,
        color=:green,
        linewidth=lw
    )
    lines!(
        ax, 
        soln["time"] .- soln["time"][1],
        z_hist,
        color=:blue,
        linewidth=lw
    )
    vlines!(
        ax,
        playhead,
        color=:yellow,
        alpha=0.7,
        linewidth=1
    )
end

function plot_spacecraft!(ax::Makie.LScene, t_jd_s, tail_length::Integer, soln::Dict)
    r_E = EARTH_EQUATORIAL_RADIUS
    arrow_scale = 0.01
    axis_scale = 0.1

    tail = zeros(3,3)
    tip = diagm([1;1;1])*r_E*axis_scale
    colors = [:red,:green,:blue]

    this_i = lift(t_jd_s) do t_jd_s
        (_,i) = findmin(x->abs(x - t_jd_s), soln["time"])
        return i
    end
    pos = lift(this_i) do this_i
        return Point3f(soln["state"][1:3,this_i])
    end
    pos_hist = lift(this_i) do this_i
        first_i = this_i - tail_length
        start_i = max(first_i, 1)
        return Point3f[(soln["state"][1:3,j]) for j in start_i:this_i]
    end
    C_BI = lift(this_i) do this_i
        C_BI_m = Matrix(reshape(soln["state"][10:18, this_i], (3,3)))
        return C_BI_m
    end
    body_axes_heads = lift(C_BI) do C_BI
        return [Vec3f(C_BI*tip[:,i]) for i in 1:3]
    end
    body_axes_tails = lift(pos) do pos
        return [Point3f(pos[:,i]) for i in 1:3]
    end
    
    scatter!(
        ax,
        pos,
        color=:yellow,
        markersize=10
    )
    lines!(
        ax,
        pos_hist,
        color=:yellow,
        linewidth=0.5,
        fxaa=true
    )
    arrows!(
        ax,
        body_axes_tails,
        body_axes_heads,
        color=colors,
        linewidth=arrow_scale*r_E,
        arrowsize=Vec3f(arrow_scale*r_E, arrow_scale*r_E, arrow_scale*3*r_E)
    )
end

function plot_targets!(ax::Makie.LScene, targets::Vector{FrameFixedTarget}, t_jd_s, eops)
    r_E = EARTH_EQUATORIAL_RADIUS
    arrow_scale = 0.01
    axis_scale = 2

    println(targets)
    celestial_targets = [target for target in targets if target.frame == :ICRS]
    ground_targets = [target for target in targets if target.frame == :ECEF]

    C_IF = lift(t_jd_s) do t_jd_s
        C_IF_r = r_ecef_to_eci(ITRF(), J2000(), t_jd_s/24/3600, eops)
        C_IF_m = Matrix(C_IF_r)
        # eci vector = C_IF * ecef vector 
        return C_IF_m
    end

    gs_pts = lift(C_IF) do C_IF
        # this is a hack---need to check that the target actually is in ECEF.
        return [Point3f(C_IF*target.position) for target in ground_targets]
    end

    # find a much less hacky way to do this:
    sun_pos = lift(t_jd_s) do t_jd_s
        sun_I = SatelliteToolboxCelestialBodies.sun_position_mod(t_jd_s/3600/24)
        sun_proj = axis_scale*r_E*sun_I/norm(sun_I)
        return [Vec3f(sun_proj)]
    end
    sun_root = lift(t_jd_s) do t_jd_s
        return [Point3f([0;0;0])]
    end

    cone_meshes = lift(C_IF) do C_IF
        nθ = 20
        nζ = 2
        θ = range(0, stop=2π, length=nθ)
        ζ = range(0, stop=6371e3*0.25, length=nζ)
        
        mesh_X = zeros(nθ, nζ, length(ground_targets))
        mesh_Y = zeros(nθ, nζ, length(ground_targets))
        mesh_Z = zeros(nθ, nζ, length(ground_targets))
        # for (k, target) in ground_targets
        for k in 1:length(ground_targets)
            # first draw cone z-up
            # then transform to align with zenith-up at target.position
            target = ground_targets[k]
            b = tan(target.cone)
            C_FT = r_min_arc([0;0;1], target.position)

            # note: currently, this ignores FixedFrameTarget.direction
            for i in 1:nθ
                for j in 1:nζ
                    # a point in the mesh
                    p = C_IF*(C_FT*[b*cos(θ[i])*ζ[j]; b*sin(θ[i])*ζ[j]; ζ[j]] + target.position)
                    mesh_X[i,j,k] = p[1]
                    mesh_Y[i,j,k] = p[2]
                    mesh_Z[i,j,k] = p[3]
                end
            end
        end
        return (mesh_X, mesh_Y, mesh_Z)
    end

    meshs = Matrix{Observable{Matrix{Float64}}}(undef, 3,length(targets))
    for i in 1:3
        for j in 1:length(ground_targets)
            meshs[i,j] = lift(cone_meshes) do globe_mesh
                return globe_mesh[i][:,:,j]
            end
        end
    end
    
    scatter!(
        ax,
        gs_pts,
        color=:lightgreen,
        markersize=10
    )

    for i in 1:length(ground_targets)
        surface!(
            ax,
            meshs[1,i],
            meshs[2,i],
            meshs[3,i],
            # color=:lightgreen,
            color=fill((:lightgreen,0.33),20,2)
        )
    end

    for i in 1:length(celestial_targets)
        if celestial_targets[i].name == "sun"
            println("plotting sun!")
            arrows!(
                ax,
                sun_root,
                sun_pos,
                color=:yellow,
                linewidth=arrow_scale*r_E,
                arrowsize=Vec3f(arrow_scale*r_E, arrow_scale*r_E, arrow_scale*3*r_E)
            )
        end
    end

end

function plot_earth!(ax::Makie.LScene, t_jd_s, iers_eops, texture_ecef)
    r_E = EARTH_EQUATORIAL_RADIUS
    r_P = EARTH_POLAR_RADIUS
    
    arrow_scale = 0.025
    axis_scale = 1.33

    tail = zeros(3,3)
    tip = diagm([1;1;1])*r_E*axis_scale
    colors = [:red,:green,:blue]

    C_IF = lift(t_jd_s) do t_jd_s
        C_IF_r = r_ecef_to_eci(ITRF(), J2000(), t_jd_s/24/3600, iers_eops)
        C_IF_m = Matrix(C_IF_r)
        # eci vector = C_IF * ecef vector 
        return C_IF_m
    end

    ecef_axes_heads = lift(C_IF) do C_IF
        return [Vec3f(C_IF*tip[:,i]) for i in 1:3]
    end

    ecef_axes_tails = lift(t_jd_s) do t_jd_s
        return [Point3f(tail[:,i]) for i in 1:3]
    end

    # drawing axes:
    arrows!(
        ax,
        ecef_axes_tails,
        ecef_axes_heads,
        color=colors,
        linewidth=arrow_scale*r_E,
        arrowsize=Vec3f(arrow_scale*r_E, arrow_scale*r_E, arrow_scale*3*r_E)
    )

    # making surface texture:
    # nθ = 3600
    nθ = length(texture_ecef[:,1])
    nφ = 100
    θ = range(0, stop=2π, length=nθ)
    φ = range(0, stop=π, length=nφ)
    # mesh_X = zeros(nθ, nφ)
    # mesh_Y = zeros(nθ, nφ)
    # mesh_Z = zeros(nθ, nφ)
    
    globe_mesh = lift(C_IF) do C_IF
        mesh_X = zeros(nθ, nφ)
        mesh_Y = zeros(nθ, nφ)
        mesh_Z = zeros(nθ, nφ)
        for i in 1:nθ
            for j in 1:nφ
                # a point in the mesh
                p = C_IF*[r_E*cos(θ[i])*sin(φ[j]); r_E*sin(θ[i])*sin(φ[j]); r_P*cos(φ[j])]
                mesh_X[i,j] = p[1]
                mesh_Y[i,j] = p[2]
                mesh_Z[i,j] = p[3]
            end
        end
        return (mesh_X, mesh_Y, mesh_Z)
    end
    X = lift(globe_mesh) do globe_mesh
        return globe_mesh[1]
    end
    Y = lift(globe_mesh) do globe_mesh
        return globe_mesh[2]
    end
    Z = lift(globe_mesh) do globe_mesh
        return globe_mesh[3]
    end

    surface!(
        ax,
        X,
        Y,
        Z,
        color=texture_ecef,
        diffuse=0.8
    )
end

function load_eops()
    return SatelliteToolboxTransformations.fetch_iers_eop()
end

function load_earth_texture_to_ecef(path::String)
    texture = load(path)
    texture = texture'
    W_uv = length(texture[:,1])
    texture = circshift(texture, (round(W_uv)/2, 0))
    return texture
end

function plot!(ax::Makie.LScene, mission::Mission)

end